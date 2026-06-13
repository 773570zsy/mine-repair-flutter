import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/hazard_provider.dart';
import '../../providers/safety_provider.dart';
import '../../services/http_client.dart';
import '../../config/api_config.dart';

import '../../config/color_constants.dart';

class HazardReportPage extends ConsumerStatefulWidget {
  const HazardReportPage({super.key});

  @override
  ConsumerState<HazardReportPage> createState() => _HazardReportPageState();
}

class _HazardReportPageState extends ConsumerState<HazardReportPage> {
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  String _severity = '一般';
  int? _responsibleId;
  String _deadline = '';
  final List<String> _photos = [];
  bool _uploading = false;

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
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
        if (url.isNotEmpty) setState(() => _photos.add(url));
      }
    } catch (_) {}
    setState(() => _uploading = false);
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera, maxWidth: 1920);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final client = HttpClient();
      final bytes = await xfile.readAsBytes();
      final resp = await client.uploadBytes('/upload/single', bytes, xfile.name, 'file');
      if (resp.isSuccess && resp.data != null) {
        final url = (resp.data as Map<String, dynamic>)['url'] ?? '';
        if (url.isNotEmpty) setState(() => _photos.add(url));
      }
    } catch (_) {}
    setState(() => _uploading = false);
  }

  Future<void> _submit() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写隐患描述')),
      );
      return;
    }
    try {
      await ref.read(hazardActionsProvider.notifier).reportHazard(
        description: desc,
        location: _locationController.text.trim(),
        severity: _severity,
        responsibleId: _responsibleId,
        deadline: _deadline,
        photosBefore: _photos.isNotEmpty ? _photos : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上报成功')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final actionsState = ref.watch(hazardActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('隐患上报'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 隐患地点
            _label('隐患地点'),
            const SizedBox(height: 4),
            _input(_locationController, '如：3号矿坑边坡'),
            const SizedBox(height: 14),

            // 严重程度
            _label('严重程度'),
            const SizedBox(height: 4),
            _severitySelector(),
            const SizedBox(height: 14),

            // 整改人
            _label('指定整改人（可选）'),
            const SizedBox(height: 4),
            usersAsync.when(
              loading: () => const SizedBox(
                height: 42,
                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
              ),
              error: (_, __) => _input(TextEditingController(), '加载失败', enabled: false),
              data: (users) => _userDropdown(users),
            ),
            const SizedBox(height: 14),

            // 整改期限
            _label('整改期限（可选）'),
            const SizedBox(height: 4),
            _datePicker(),
            const SizedBox(height: 14),

            // 隐患描述
            _label('隐患描述 *'),
            const SizedBox(height: 4),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: _inputDecoration('请详细描述隐患情况...'),
            ),
            const SizedBox(height: 14),

            // 照片
            _label('隐患照片'),
            const SizedBox(height: 4),
            if (_photos.isNotEmpty) ...[
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _photos.map((url) => _photoPreview(url)).toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                _photoBtn(Icons.photo_library, '相册', _pickPhoto),
                const SizedBox(width: 8),
                _photoBtn(Icons.camera_alt, '拍照', _takePhoto),
                if (_uploading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // 提交
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: actionsState.loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: actionsState.loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                    : const Text('提交上报', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, color: AppColors.text2, fontWeight: FontWeight.w500));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.text2, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF2a2e38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, {bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: _inputDecoration(hint),
    );
  }

  Widget _severitySelector() {
    final items = ['低', '一般', '高', '紧急'];
    return Wrap(
      spacing: 8,
      children: items.map((s) {
        final selected = _severity == s;
        Color color;
        switch (s) {
          case '低': color = const Color(0xFF5a9e5f); break;
          case '一般': color = const Color(0xFFd4a017); break;
          case '高':
          case '紧急': color = const Color(0xFFe05555); break;
          default: color = AppColors.text2;
        }
        return GestureDetector(
          onTap: () => setState(() => _severity = s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.15) : const Color(0xFF2a2e38),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selected ? color : AppColors.border),
            ),
            child: Text(s, style: TextStyle(fontSize: 13, color: selected ? color : AppColors.text2, fontWeight: FontWeight.w500)),
          ),
        );
      }).toList(),
    );
  }

  Widget _userDropdown(List<Map<String, dynamic>> users) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2e38),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<int?>(
        value: _responsibleId,
        isExpanded: true,
        dropdownColor: const Color(0xFF2a2e38),
        style: const TextStyle(color: AppColors.text, fontSize: 14),
        underline: const SizedBox(),
        hint: const Text('暂不指定', style: TextStyle(color: AppColors.text2, fontSize: 14)),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('暂不指定', style: TextStyle(color: AppColors.text2))),
          ...users.map((u) => DropdownMenuItem<int?>(
                value: u['id'] as int,
                child: Text('${u['name']}（${u['role']}）', style: const TextStyle(color: AppColors.text)),
              )),
        ],
        onChanged: (v) => setState(() => _responsibleId = v),
      ),
    );
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 3)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.gold),
            ),
            child: child!,
          ),
        );
        if (date != null) {
          setState(() => _deadline = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2e38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _deadline.isNotEmpty ? _deadline : '点击选择日期',
          style: TextStyle(fontSize: 14, color: _deadline.isNotEmpty ? AppColors.text : AppColors.text2),
        ),
      ),
    );
  }

  Widget _photoPreview(String url) {
    final fullUrl = url.startsWith('http') ? url : ApiConfig.fileUrl(url);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(fullUrl, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0, right: 0,
          child: GestureDetector(
            onTap: () => setState(() => _photos.remove(url)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Color(0xFFe05555), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4))),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2e38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.text2),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          ],
        ),
      ),
    );
  }
}
