import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/vehicle.dart';
import '../../providers/inspection_provider.dart';
import '../../config/api_config.dart';
import '../../services/http_client.dart';

import '../../config/color_constants.dart';

class EveningCheckPage extends ConsumerStatefulWidget {
  const EveningCheckPage({super.key});

  @override
  ConsumerState<EveningCheckPage> createState() => _EveningCheckPageState();
}

class _EveningCheckPageState extends ConsumerState<EveningCheckPage> {
  int? _vehicleId;
  final _endHoursCtrl = TextEditingController();
  final _fuelAmountCtrl = TextEditingController();
  final _parkingLocationCtrl = TextEditingController();
  final _endKmCtrl = TextEditingController();
  final List<String> _photos = [];
  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void dispose() {
    _endHoursCtrl.dispose();
    _fuelAmountCtrl.dispose();
    _parkingLocationCtrl.dispose();
    _endKmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }

  Future<void> _submit() async {
    if (_vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择车辆')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(inspectionActionsProvider.notifier).submitEveningCheck(
        vehicleId: _vehicleId!,
        endHours: double.tryParse(_endHoursCtrl.text) ?? 0,
        fuelAmount: double.tryParse(_fuelAmountCtrl.text) ?? 0,
        attendanceSymbol: '',
        parkingLocation: _parkingLocationCtrl.text,
        endKm: double.tryParse(_endKmCtrl.text) ?? 0,
        photos: _photos,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('晚检提交成功')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('晚检'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
        data: (vehicles) => SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildVehiclePicker(vehicles),
            const SizedBox(height: 16),
            _buildField('下班工时', _endHoursCtrl, keyboardType: TextInputType.number),
            _buildField('加油量(L)', _fuelAmountCtrl, keyboardType: TextInputType.number),
            _buildField('停车地点', _parkingLocationCtrl),
            _buildField('下班公里数', _endKmCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildPhotoSection(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_submitting ? '提交中...' : '提交晚检', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildVehiclePicker(List<Vehicle> vehicles) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('选择车辆', style: TextStyle(color: AppColors.text2, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          value: _vehicleId,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          ),
          hint: const Text('请选择车辆', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          items: vehicles.map((v) => DropdownMenuItem<int?>(
            value: v.id,
            child: Text('${v.plateNumber} (${v.vehicleType})', style: const TextStyle(color: AppColors.text, fontSize: 13)),
          )).toList(),
          onChanged: (v) => setState(() => _vehicleId = v),
        ),
      ]),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('现场照片', style: TextStyle(color: AppColors.text2, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ..._photos.map((path) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  ApiConfig.fileUrl(path),
                  width: 80, height: 80, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppColors.border, child: const Icon(Icons.broken_image, color: AppColors.text2)),
                ),
              ),
              Positioned(
                top: 0, right: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _photos.remove(path)),
                  child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(2)), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                ),
              ),
            ],
          )),
          _photoBtn(Icons.camera_alt, '拍照', () => _pickPhoto(ImageSource.camera)),
          _photoBtn(Icons.photo_library, '相册', () => _pickPhoto(ImageSource.gallery)),
        ]),
      ]),
    );
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
        ),
      ),
    );
  }
}
