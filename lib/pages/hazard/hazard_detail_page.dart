import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/hazard_provider.dart';
import '../../providers/safety_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/http_client.dart';
import '../../config/api_config.dart';

import '../../config/color_constants.dart';
import '../../widgets/photo_viewer.dart';

class HazardDetailPage extends ConsumerStatefulWidget {
  final int hazardId;
  const HazardDetailPage({super.key, required this.hazardId});

  @override
  ConsumerState<HazardDetailPage> createState() => _HazardDetailPageState();
}

class _HazardDetailPageState extends ConsumerState<HazardDetailPage> {
  final _rectifyDescController = TextEditingController();
  final List<String> _rectifyPhotos = [];
  bool _uploading = false;

  @override
  void dispose() {
    _rectifyDescController.dispose();
    super.dispose();
  }

  Future<void> _pickRectifyPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final client = HttpClient();
      final bytes = await xfile.readAsBytes();
      final resp = await client.uploadBytes('/upload/single', bytes, xfile.name, 'file');
      if (resp.isSuccess && resp.data != null) {
        final url = (resp.data as Map<String, dynamic>)['url'] ?? '';
        if (url.isNotEmpty) setState(() => _rectifyPhotos.add(url));
      }
    } catch (_) {}
    setState(() => _uploading = false);
  }

  String _photoUrl(String path) {
    if (path.startsWith('http')) return path;
    return ApiConfig.fileUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(hazardDetailProvider(widget.hazardId));
    final user = ref.watch(authProvider).user;

    // 监听操作结果
    ref.listen<HazardActionsState>(hazardActionsProvider, (prev, next) {
      if (next.successMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMsg!)));
        ref.read(hazardActionsProvider.notifier).clearMessages();
        ref.invalidate(hazardDetailProvider(widget.hazardId));
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.danger));
        ref.read(hazardActionsProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('隐患详情'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
        data: (hazard) {
          if (hazard == null) {
            return const Center(child: Text('隐患不存在', style: TextStyle(color: AppColors.text2)));
          }
          return _buildDetail(hazard, user);
        },
      ),
    );
  }

  Widget _buildDetail(hazard, user) {
    final isSafety = user?.role == 'safety_officer' || user?.role == 'admin';
    final isReporter = user?.id == hazard.reporterId;
    final isResponsible = user?.id == hazard.responsibleId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息卡片
          _sectionCard([
            _infoRow('隐患编号', hazard.hazardNo),
            _infoRow('状态', hazard.statusLabel, valueColor: _statusColor(hazard.status)),
            _infoRow('严重程度', hazard.severity, valueColor: _severityColor(hazard.severity)),
            _infoRow('上报人', hazard.reporterName ?? ''),
            _infoRow('整改人', hazard.responsibleName ?? '未指定'),
            _infoRow('整改期限', hazard.deadline.isNotEmpty ? hazard.deadline : '无'),
            _infoRow('上报时间', hazard.createdAt.isNotEmpty ? hazard.createdAt.substring(0, 16) : ''),
          ]),
          const SizedBox(height: 10),

          // 地点
          _sectionCard([
            _infoRow('隐患地点', hazard.location.isNotEmpty ? hazard.location : '未指定'),
          ]),
          const SizedBox(height: 10),

          // 描述
          _sectionCard([
            _sectionTitle('隐患描述'),
            const SizedBox(height: 4),
            Text(hazard.description, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ]),
          const SizedBox(height: 10),

          // 整改前照片
          if (hazard.photosBefore != null && hazard.photosBefore!.isNotEmpty) ...[
            _sectionCard([
              _sectionTitle('整改前照片'),
              const SizedBox(height: 8),
              _photoGrid(hazard.photosBefore!),
            ]),
            const SizedBox(height: 10),
          ],

          // 整改后照片
          if (hazard.photosAfter != null && hazard.photosAfter!.isNotEmpty) ...[
            _sectionCard([
              _sectionTitle('整改后照片'),
              const SizedBox(height: 8),
              _photoGrid(hazard.photosAfter!),
            ]),
            const SizedBox(height: 10),
          ],

          // 整改说明
          if (hazard.rectifyDesc != null && hazard.rectifyDesc!.isNotEmpty) ...[
            _sectionCard([
              _sectionTitle('整改说明'),
              const SizedBox(height: 4),
              Text(hazard.rectifyDesc!, style: const TextStyle(fontSize: 14, color: AppColors.text)),
            ]),
            const SizedBox(height: 10),
          ],

          // 驳回原因
          if (hazard.rejectReason != null && hazard.rejectReason!.isNotEmpty) ...[
            _sectionCard([
              _sectionTitle('驳回原因'),
              const SizedBox(height: 4),
              Text(hazard.rejectReason!,
                  style: const TextStyle(fontSize: 14, color: AppColors.danger)),
            ]),
            const SizedBox(height: 10),
          ],

          // 整改人操作区：提交整改（内联表单）
          if (hazard.canRectify && isResponsible) ...[
            _sectionCard([
              _sectionTitle('提交整改'),
              const SizedBox(height: 8),
              // 照片预览
              if (_rectifyPhotos.isNotEmpty) ...[
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _rectifyPhotos.map((url) => _rectifyPhotoPreview(url)).toList(),
                ),
                const SizedBox(height: 8),
              ],
              // 添加照片按钮
              GestureDetector(
                onTap: _pickRectifyPhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate, size: 16, color: AppColors.text2),
                      const SizedBox(width: 4),
                      Text(_uploading ? '上传中...' : '添加照片', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 整改说明
              TextField(
                controller: _rectifyDescController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '请填写整改说明...',
                  hintStyle: const TextStyle(color: AppColors.text2),
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.success, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () async {
                    final desc = _rectifyDescController.text.trim();
                    if (desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写整改说明')));
                      return;
                    }
                    try {
                      await ref.read(hazardActionsProvider.notifier).rectifyHazard(
                        hazard.id, _rectifyPhotos, desc);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())));
                      }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: const Text('提交整改', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
          ],

          // 操作按钮区
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 30),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                // 指派按钮（待指派 + 安全员/管理员）
                if (hazard.canAssign && isSafety)
                  _actionBtn('指定整改人', AppColors.warning, () => _showAssignDialog(hazard.id)),
                // 验收通过（待确认 + 安全员或上报人）
                if (hazard.canVerify && (isSafety || isReporter))
                  _actionBtn('验收通过', AppColors.success, () => _confirmVerify(hazard.id)),
                // 驳回（待确认 + 安全员或上报人）
                if (hazard.canVerify && (isSafety || isReporter))
                  _actionBtn('驳回整改', AppColors.danger, () => _showRejectDialog(hazard.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2));
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? AppColors.text, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _photoGrid(List<String> photos) {
    final fullUrls = photos.map((u) => _photoUrl(u)).toList();
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: fullUrls.asMap().entries
          .map((e) => _photoThumb(e.value, allUrls: fullUrls, index: e.key))
          .toList(),
    );
  }

  Widget _photoThumb(String url, {List<String>? allUrls, int? index}) {
    return GestureDetector(
      onTap: () => _showFullScreen(allUrls ?? [url], index ?? 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 80, height: 80, color: AppColors.surface2,
            child: const Icon(Icons.broken_image, color: AppColors.text2, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _rectifyPhotoPreview(String url) {
    final fullUrl = _photoUrl(url);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(fullUrl, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0, right: 0,
          child: GestureDetector(
            onTap: () => setState(() => _rectifyPhotos.remove(url)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4))),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreen(List<String> urls, int startIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PhotoViewer(images: urls, initialIndex: startIndex),
    ));
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  void _showAssignDialog(int hazardId) {
    final usersAsync = ref.read(allUsersProvider);
    usersAsync.whenData((users) {
      int? selectedUserId;
      String deadline = '';
      showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('指派整改人', style: TextStyle(color: AppColors.text)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButton<int>(
                      value: selectedUserId,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      style: const TextStyle(color: AppColors.text, fontSize: 14),
                      underline: const SizedBox(),
                      hint: const Text('选择整改人', style: TextStyle(color: AppColors.text2, fontSize: 14)),
                      items: users.map((u) => DropdownMenuItem<int>(
                            value: u['id'] as int,
                            child: Text('${u['name']}（${u['role']}）', style: const TextStyle(color: AppColors.text)),
                          )).toList(),
                      onChanged: (v) => setDialogState(() => selectedUserId = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold)),
                          child: child!,
                        ),
                      );
                      if (date != null) {
                        final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        setDialogState(() => deadline = d);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        deadline.isNotEmpty ? deadline : '选择整改期限',
                        style: TextStyle(fontSize: 14, color: deadline.isNotEmpty ? AppColors.text : AppColors.text2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
                ElevatedButton(
                  onPressed: selectedUserId == null ? null : () {
                    Navigator.pop(ctx);
                    ref.read(hazardActionsProvider.notifier).assignHazard(hazardId, selectedUserId!, deadline);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
                  child: const Text('确定指派'),
                ),
              ],
            );
          });
        },
      );
    });
  }

  void _confirmVerify(int hazardId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认验收', style: TextStyle(color: AppColors.text)),
        content: const Text('确认该隐患整改验收通过？', style: TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(hazardActionsProvider.notifier).verifyHazard(hazardId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('确认验收'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(int hazardId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('驳回整改', style: TextStyle(color: AppColors.text)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: '请填写驳回原因...',
            hintStyle: const TextStyle(color: AppColors.text2),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              ref.read(hazardActionsProvider.notifier).rejectRectify(hazardId, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case '低': return AppColors.success;
      case '一般': return AppColors.warning;
      case '高':
      case '紧急': return AppColors.danger;
      default: return AppColors.text2;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reported':
      case 'assigned':
        return AppColors.warning;
      case 'rectifying':
        return const Color(0xFF7a8a9a);
      case 'completed':
        return AppColors.warning;
      case 'verified':
        return AppColors.success;
      default:
        return AppColors.text2;
    }
  }
}
