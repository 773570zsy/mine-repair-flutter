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

class MorningCheckPage extends ConsumerStatefulWidget {
  const MorningCheckPage({super.key});

  @override
  ConsumerState<MorningCheckPage> createState() => _MorningCheckPageState();
}

class _MorningCheckPageState extends ConsumerState<MorningCheckPage> {
  int? _vehicleId;
  String _oilLevel = 'high';
  String _coolantLevel = 'high';
  String _appearance = 'normal';
  String _tireCondition = 'normal';
  String _toolkitCheck = 'normal';
  String _mentalState = 'normal';
  String _ppeWearing = 'ok';
  String _overallStatus = 'normal';
  final _abnormalDescCtrl = TextEditingController();
  final _startHoursCtrl = TextEditingController();
  final _startKmCtrl = TextEditingController();
  final _bpHighCtrl = TextEditingController();
  final _bpLowCtrl = TextEditingController();
  final List<String> _photos = [];
  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void dispose() {
    _abnormalDescCtrl.dispose();
    _startHoursCtrl.dispose();
    _startKmCtrl.dispose();
    _bpHighCtrl.dispose();
    _bpLowCtrl.dispose();
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
      await ref.read(inspectionActionsProvider.notifier).submitMorningCheck(
        vehicleId: _vehicleId!,
        oilLevel: _oilLevel,
        coolantLevel: _coolantLevel,
        appearance: _appearance,
        tireCondition: _tireCondition,
        toolkitCheck: _toolkitCheck,
        overallStatus: _overallStatus,
        abnormalDesc: _abnormalDescCtrl.text,
        notes: '',
        startHours: double.tryParse(_startHoursCtrl.text) ?? 0,
        startKm: double.tryParse(_startKmCtrl.text) ?? 0,
        photos: _photos,
        mentalState: _mentalState,
        ppeWearing: _ppeWearing,
        bloodPressureHigh: int.tryParse(_bpHighCtrl.text) ?? 0,
        bloodPressureLow: int.tryParse(_bpLowCtrl.text) ?? 0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('早检提交成功')));
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
      appBar: AppBar(title: const Text('早检'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
        data: (vehicles) => SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildVehiclePicker(vehicles),
            const SizedBox(height: 16),
            _buildSelectRow('机油油位', _oilLevel, ['high', 'mid', 'low'], (v) => setState(() => _oilLevel = v)),
            _buildSelectRow('冷却液位', _coolantLevel, ['high', 'mid', 'low'], (v) => setState(() => _coolantLevel = v)),
            _buildSelectRow('外观情况', _appearance, ['normal', 'damaged', 'dirty'], (v) => setState(() => _appearance = v)),
            _buildSelectRow('轮胎状况', _tireCondition, ['normal', 'worn', 'damaged'], (v) => setState(() => _tireCondition = v)),
            _buildSelectRow('随车九样物品', _toolkitCheck, ['ok', 'missing'], (v) => setState(() => _toolkitCheck = v)),
            _buildSelectRow('个人精神状态', _mentalState, ['normal', 'abnormal'], (v) => setState(() => _mentalState = v), labels: {'abnormal': '不正常'}),
            _buildSelectRow('劳保用品穿戴', _ppeWearing, ['ok', 'missing'], (v) => setState(() => _ppeWearing = v)),
            _buildSelectRow('总体状态', _overallStatus, ['normal', 'abnormal'], (v) => setState(() => _overallStatus = v)),
            const SizedBox(height: 12),
            // 血压
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('血压填写', style: TextStyle(color: AppColors.text2, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _bpHighCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '高压',
                      hintText: '收缩压',
                      labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
                      hintStyle: const TextStyle(color: AppColors.text2, fontSize: 11),
                      filled: true, fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    controller: _bpLowCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '低压',
                      hintText: '舒张压',
                      labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
                      hintStyle: const TextStyle(color: AppColors.text2, fontSize: 11),
                      filled: true, fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
                    ),
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            _buildTextField('上班工时', _startHoursCtrl, keyboardType: TextInputType.number),
            _buildTextField('上班公里数', _startKmCtrl, keyboardType: TextInputType.number),
            _buildTextField('异常描述', _abnormalDescCtrl, maxLines: 2),
            const SizedBox(height: 12),
            // 照片
            _buildPhotoSection(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_submitting ? '提交中...' : '提交早检', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildSelectRow(String label, String value, List<String> options, ValueChanged<String> onChanged, {Map<String, String>? labels}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 13))),
        ...options.map((o) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: value == o ? AppColors.gold.withValues(alpha: 0.2) : AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: value == o ? AppColors.gold : AppColors.border),
              ),
              child: Text(_optionLabel(o, labels: labels), style: TextStyle(color: value == o ? AppColors.gold : AppColors.text2, fontSize: 12)),
            ),
          ),
        )),
      ]),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('血压/点检照片上传', style: TextStyle(color: AppColors.text2, fontSize: 13)),
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

  String _optionLabel(String v, {Map<String, String>? labels}) {
    if (labels != null && labels.containsKey(v)) return labels[v]!;
    const map = {
      'high': '高位', 'mid': '中位', 'low': '低位',
      'normal': '正常', 'damaged': '有损坏', 'dirty': '需清洁',
      'worn': '磨损', 'ok': '齐全', 'missing': '缺失', 'abnormal': '异常',
    };
    return map[v] ?? v;
  }
}
