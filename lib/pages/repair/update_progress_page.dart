import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../providers/repair_provider.dart';
import '../../config/api_config.dart';
import '../../services/http_client.dart';

/// 修理厂更新维修进度（或完工）
class UpdateProgressPage extends ConsumerStatefulWidget {
  final int orderId;
  final bool isComplete; // true=完工, false=更新进度

  const UpdateProgressPage({
    super.key,
    required this.orderId,
    this.isComplete = false,
  });

  @override
  ConsumerState<UpdateProgressPage> createState() => _UpdateProgressPageState();
}

class _UpdateProgressPageState extends ConsumerState<UpdateProgressPage> {
  final _contentController = TextEditingController();
  final List<String> _photos = [];
  final List<String> _newPhotos = [];
  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      _uploadPhoto(bytes, xfile.name);
    }
  }

  Future<void> _uploadPhoto(Uint8List bytes, String filename) async {
    try {
      final client = HttpClient();
      final resp = await client.uploadBytes('/upload/single', bytes, filename, 'file');
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? resp.data as Map : null;
        final url = data?['url']?.toString() ?? data?['path']?.toString() ?? '';
        if (url.isNotEmpty) setState(() => _photos.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('上传照片失败: $e')));
      }
    }
  }

  Future<void> _pickNewPhoto() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      _uploadNewPhoto(bytes, xfile.name);
    }
  }

  Future<void> _uploadNewPhoto(Uint8List bytes, String filename) async {
    try {
      final client = HttpClient();
      final resp = await client.uploadBytes('/upload/single', bytes, filename, 'file');
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? resp.data as Map : null;
        final url = data?['url']?.toString() ?? data?['path']?.toString() ?? '';
        if (url.isNotEmpty) setState(() => _newPhotos.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传照片失败: $e')));
      }
    }
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showMsg(widget.isComplete ? '请填写完工说明' : '请填写进度内容');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.isComplete) {
        await ref.read(repairActionsProvider.notifier).completeOrder(widget.orderId, newPhotos: _newPhotos);
      } else {
        await ref.read(repairActionsProvider.notifier).updateProgress(
              orderId: widget.orderId,
              content: content,
              images: _photos,
            );
      }
      if (mounted) {
        _showMsg(widget.isComplete ? '完工通知已发送' : '进度更新成功');
        ref.invalidate(orderDetailProvider(widget.orderId));
        context.pop();
      }
    } catch (e) {
      _showMsg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isComplete ? '维修完工' : '更新进度';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isComplete)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '确认完工后将通知驾驶员验收',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // 内容输入
            TextField(
              controller: _contentController,
              maxLines: widget.isComplete ? 3 : 4,
              decoration: InputDecoration(
                labelText: widget.isComplete ? '完工说明' : '维修进度描述 *',
                hintText: widget.isComplete
                    ? '简述维修完成情况...'
                    : '描述当前维修进度，如已更换的配件等...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Icon(
                  widget.isComplete ? Icons.check_circle : Icons.build,
                  color: const Color(0xFFc8a04a),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 照片（进度更新：维修照片；完工：新配件照片）
            if (!widget.isComplete) ...[
              Text('维修照片（选填）',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._photos.map((path) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _photoUrl(path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 80,
                                height: 80,
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red, size: 20),
                              onPressed: () =>
                                  setState(() => _photos.remove(path)),
                            ),
                          ),
                        ],
                      )),
                  _addPhotoBtn(),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text('新配件照片',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._newPhotos.map((path) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _photoUrl(path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 80,
                                height: 80,
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red, size: 20),
                              onPressed: () =>
                                  setState(() => _newPhotos.remove(path)),
                            ),
                          ),
                        ],
                      )),
                  _addNewPhotoBtn(),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 提交
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isComplete
                    ? Colors.green.shade600
                    : const Color(0xFFc8a04a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addPhotoBtn() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: Colors.grey.shade600, size: 24),
            Text('拍照', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _addNewPhotoBtn() {
    return GestureDetector(
      onTap: _pickNewPhoto,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: Colors.grey.shade600, size: 24),
            Text('拍照', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  String _photoUrl(String path) {
    return ApiConfig.fileUrl(path);
  }
}
