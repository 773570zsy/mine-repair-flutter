import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../models/vehicle.dart';
import '../../providers/repair_provider.dart';
import '../../providers/external_repair_provider.dart';
import '../../config/api_config.dart';
import '../../services/http_client.dart';

class ReportFaultPage extends ConsumerStatefulWidget {
  const ReportFaultPage({super.key});

  @override
  ConsumerState<ReportFaultPage> createState() => _ReportFaultPageState();
}

class _ReportFaultPageState extends ConsumerState<ReportFaultPage> {
  Vehicle? _selectedVehicle;
  int? _selectedShopId;
  final _descController = TextEditingController();
  final _descFocus = FocusNode();
  final List<String> _photos = [];
  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    _descFocus.dispose();
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

  Future<void> _pickGallery() async {
    final xfiles = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
    );
    for (final xf in xfiles) {
      final bytes = await xf.readAsBytes();
      _uploadPhoto(bytes, xf.name);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传照片失败: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedVehicle == null) {
      _showMsg('请选择车辆');
      return;
    }
    if (_selectedShopId == null) {
      _showMsg('请选择修理厂');
      return;
    }
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      _showMsg('请填写故障描述');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(repairActionsProvider.notifier).reportFault(
            vehicleId: _selectedVehicle!.id,
            faultDescription: desc,
            faultImages: _photos,
            repairShopId: _selectedShopId,
          );
      if (mounted) {
        _showMsg('报修成功');
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
    final vehiclesAsync = ref.watch(vehicleListProvider);
    final shopsAsync = ref.watch(externalShopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('发起报修'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 车辆选择
            vehiclesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('加载车辆失败: $e',
                  style: const TextStyle(color: Colors.red)),
              data: (vehicles) {
                final available = vehicles
                    .where((v) => v.isNormal)
                    .toList();
                if (available.isEmpty) {
                  return const Card(
                    color: Colors.orange,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('暂无可用的正常状态车辆',
                          style: TextStyle(color: Colors.white)),
                    ),
                  );
                }
                return DropdownButtonFormField<Vehicle>(
                  initialValue: _selectedVehicle,
                  decoration: const InputDecoration(
                    labelText: '选择车辆 *',
                    prefixIcon: Icon(Icons.directions_car),
                    border: OutlineInputBorder(),
                  ),
                  items: available
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.displayLabel),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedVehicle = v),
                );
              },
            ),
            const SizedBox(height: 16),

            // 修理厂选择
            shopsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (shops) {
                if (shops.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<int>(
                  value: _selectedShopId,
                  decoration: const InputDecoration(
                    labelText: '选择修理厂 *',
                    hintText: '请选择修理厂',
                    prefixIcon: Icon(Icons.build),
                    border: OutlineInputBorder(),
                  ),
                  items: shops.map((s) => DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text(s['name'] as String),
                      )).toList(),
                  onChanged: (v) => setState(() => _selectedShopId = v),
                );
              },
            ),
            const SizedBox(height: 16),

            // 故障描述
            TextField(
              controller: _descController,
              focusNode: _descFocus,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '故障描述 *',
                hintText: '请详细描述车辆故障情况...',
                prefixIcon: Icon(Icons.description, color: Color(0xFFc8a04a)),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // 照片区域
            Text('故障照片',
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
                // 添加按钮
                _buildPhotoButton(Icons.camera_alt, '拍照', _pickPhoto),
                _buildPhotoButton(Icons.photo_library, '相册', _pickGallery),
              ],
            ),
            const SizedBox(height: 24),

            // 提交按钮
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc8a04a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('提交报修',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoButton(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 24),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  String _photoUrl(String path) {
    return ApiConfig.fileUrl(path);
  }
}
