import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../providers/vehicle_archive_provider.dart';
import '../../services/http_client.dart';

import '../../config/color_constants.dart';

class ArchiveFormPage extends ConsumerStatefulWidget {
  final String? plateNumber; // null = 新增, 有值 = 编辑
  const ArchiveFormPage({super.key, this.plateNumber});

  @override
  ConsumerState<ArchiveFormPage> createState() => _ArchiveFormPageState();
}

class _ArchiveFormPageState extends ConsumerState<ArchiveFormPage> {
  bool _loading = false;
  bool _isEdit = false;
  bool _useHoursMaintenance = true; // true=工时保养, false=公里保养

  // 控制器
  final _plateCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _manufactureDateCtrl = TextEditingController();
  final _purchaseDateCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _insuranceCtrl = TextEditingController();
  final _inspectionDateCtrl = TextEditingController();
  final _maintenanceIntervalCtrl = TextEditingController(text: '500');
  final _nextMaintenanceHoursCtrl = TextEditingController(text: '0');
  final _maintenanceIntervalKmCtrl = TextEditingController(text: '0');
  final _nextMaintenanceKmCtrl = TextEditingController(text: '0');
  final _currentKmCtrl = TextEditingController(text: '0');
  final _assetValueCtrl = TextEditingController(text: '0');
  final _hourlyRateCtrl = TextEditingController(text: '0');

  String _department = '总调度室';
  bool _hasBehaviorMonitor = false;
  bool _has360Camera = false;
  final List<String> _photos = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEdit = widget.plateNumber != null;
    if (_isEdit) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final detail = await ref.read(vehicleArchiveDetailProvider(widget.plateNumber!).future);
    if (detail != null && mounted) {
      setState(() {
        _plateCtrl.text = detail.plateNumber;
        _typeCtrl.text = detail.vehicleType ?? '';
        _modelCtrl.text = detail.model ?? '';
        _manufactureDateCtrl.text = detail.manufactureDate ?? '';
        _purchaseDateCtrl.text = detail.purchaseDate ?? '';
        _vinCtrl.text = detail.vin ?? '';
        _insuranceCtrl.text = detail.insuranceExpiry ?? '';
        _inspectionDateCtrl.text = detail.inspectionDate ?? '';
        _maintenanceIntervalCtrl.text = detail.maintenanceInterval.toString();
        _nextMaintenanceHoursCtrl.text = detail.nextMaintenanceHours.toString();
        _maintenanceIntervalKmCtrl.text = detail.maintenanceIntervalKm.toString();
        _nextMaintenanceKmCtrl.text = detail.nextMaintenanceKm.toString();
        _currentKmCtrl.text = detail.currentKm.toString();
        _assetValueCtrl.text = detail.assetValue > 0 ? detail.assetValue.toString() : '';
        _hourlyRateCtrl.text = detail.hourlyRate > 0 ? detail.hourlyRate.toString() : '';
        _department = detail.department ?? '总调度室';
        _hasBehaviorMonitor = detail.hasBehaviorMonitor;
        _has360Camera = detail.has360Camera;
        _photos.addAll(detail.photos);
        _useHoursMaintenance = detail.useHoursMaintenance;
        if (!detail.useHoursMaintenance && !detail.useKmMaintenance) {
          _useHoursMaintenance = true; // 默认工时
        }
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
    if (xfile != null) {
      try {
        final client = HttpClient();
        final bytes = await xfile.readAsBytes();
        final resp = await client.uploadBytes('/upload/single', bytes, xfile.name, 'file');
        if (resp.isSuccess && resp.data != null) {
          final data = resp.data is Map ? resp.data as Map : null;
          final url = data?['url']?.toString() ?? data?['path']?.toString() ?? '';
          if (url.isNotEmpty) setState(() => _photos.add(url));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
        }
      }
    }
  }

  Future<void> _submit() async {
    final plate = _plateCtrl.text.trim();
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入内部编号')));
      return;
    }

    setState(() => _loading = true);
    final data = {
      'plate_number': plate,
      'department': _department,
      'vehicle_type': _typeCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'manufacture_date': _manufactureDateCtrl.text.trim(),
      'purchase_date': _purchaseDateCtrl.text.trim(),
      'asset_value': double.tryParse(_assetValueCtrl.text) ?? 0,
      'hourly_rate': double.tryParse(_hourlyRateCtrl.text) ?? 0,
      'vin': _vinCtrl.text.trim(),
      'insurance_expiry': _insuranceCtrl.text.trim(),
      'inspection_date': _inspectionDateCtrl.text.trim(),
      // 工时保养：活跃时取表单值，否则清零
      'maintenance_interval': _useHoursMaintenance ? (int.tryParse(_maintenanceIntervalCtrl.text) ?? 500) : 0,
      'next_maintenance_hours': _useHoursMaintenance ? (int.tryParse(_nextMaintenanceHoursCtrl.text) ?? 0) : 0,
      // 公里保养：活跃时取表单值，否则清零
      'maintenance_interval_km': !_useHoursMaintenance ? (int.tryParse(_maintenanceIntervalKmCtrl.text) ?? 10000) : 0,
      'next_maintenance_km': !_useHoursMaintenance ? (int.tryParse(_nextMaintenanceKmCtrl.text) ?? 0) : 0,
      'current_km': !_useHoursMaintenance ? (int.tryParse(_currentKmCtrl.text) ?? 0) : 0,
      'has_behavior_monitor': _hasBehaviorMonitor,
      'has_360_camera': _has360Camera,
      'photos': _photos,
    };

    try {
      if (_isEdit) {
        await ref.read(vehicleArchiveActionsProvider.notifier).update(widget.plateNumber!, data);
      } else {
        await ref.read(vehicleArchiveActionsProvider.notifier).create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? '档案已更新' : '档案已创建')),
        );
        if (_isEdit && plate != widget.plateNumber) {
          // 内部编号已改，旧详情页失效，直接回列表
          context.go('/vehicle-archive/list');
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose(); _typeCtrl.dispose(); _modelCtrl.dispose();
    _manufactureDateCtrl.dispose(); _purchaseDateCtrl.dispose(); _vinCtrl.dispose();
    _insuranceCtrl.dispose(); _inspectionDateCtrl.dispose();
    _maintenanceIntervalCtrl.dispose(); _nextMaintenanceHoursCtrl.dispose();
    _maintenanceIntervalKmCtrl.dispose(); _nextMaintenanceKmCtrl.dispose();
    _currentKmCtrl.dispose(); _assetValueCtrl.dispose(); _hourlyRateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑车辆档案' : '添加车辆档案'),
        backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('基本信息', [
              _field('内部编号 *', _plateCtrl, hint: '如：矿A-001', enabled: true),
              _dropdownField('所属部门 *', _department, ['总调度室', '西藏恒骏'], (v) => setState(() => _department = v)),
              _field('类型', _typeCtrl, hint: '如：履带挖掘机'),
              _field('具体型号', _modelCtrl, hint: '如：CAT 390D'),
              _dateField('出厂日期', _manufactureDateCtrl),
              _dateField('购买日期', _purchaseDateCtrl),
              _field('资产净值(元)', _assetValueCtrl, hint: '车辆购置价值', keyboardType: TextInputType.number),
              _field('小时单价(元/h)', _hourlyRateCtrl, hint: '机械台班结算单价', keyboardType: TextInputType.number),
              _field('车辆识别代码(VIN)', _vinCtrl, hint: 'VIN码'),
              _dateField('保险到期日', _insuranceCtrl),
              _dateField('年检日期', _inspectionDateCtrl),
            ]),
            const SizedBox(height: 14),
            _buildSection('保养设置', [
              // 保养模式切换
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useHoursMaintenance = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _useHoursMaintenance ? AppColors.gold.withValues(alpha: 0.15) : AppColors.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _useHoursMaintenance ? AppColors.gold : AppColors.border),
                        ),
                        child: const Center(
                          child: Text('⏱ 工时保养', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useHoursMaintenance = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_useHoursMaintenance ? AppColors.gold.withValues(alpha: 0.15) : AppColors.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: !_useHoursMaintenance ? AppColors.gold : AppColors.border),
                        ),
                        child: const Center(
                          child: Text('🛣 公里保养', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 工时保养字段
              if (_useHoursMaintenance) ...[
                _field('保养间隔(h)', _maintenanceIntervalCtrl, keyboardType: TextInputType.number),
                _field('下次保养工时', _nextMaintenanceHoursCtrl, keyboardType: TextInputType.number),
              ],
              // 公里保养字段
              if (!_useHoursMaintenance) ...[
                _field('保养间隔(km)', _maintenanceIntervalKmCtrl, keyboardType: TextInputType.number),
                _field('下次保养公里', _nextMaintenanceKmCtrl, keyboardType: TextInputType.number),
                _field('当前公里', _currentKmCtrl, keyboardType: TextInputType.number),
              ],
            ]),
            const SizedBox(height: 14),
            _buildSection('监控设备', [
              _switchTile('行为监控', _hasBehaviorMonitor, (v) => setState(() => _hasBehaviorMonitor = v)),
              _switchTile('360环影', _has360Camera, (v) => setState(() => _has360Camera = v)),
            ]),
            const SizedBox(height: 14),
            _buildPhotoSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold, foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _loading ? '提交中...' : (_isEdit ? '保存修改' : '创建档案'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final initial = ctrl.text.isNotEmpty
        ? DateTime.tryParse(ctrl.text)
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: AppColors.bg,
            surface: AppColors.surface,
            onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _dateField(String label, TextEditingController ctrl, {String? hint, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        readOnly: true,
        onTap: enabled ? () => _pickDate(ctrl) : null,
        style: TextStyle(color: enabled ? AppColors.text : AppColors.text2, fontSize: 13),
        decoration: InputDecoration(
          labelText: label, hintText: hint ?? 'YYYY-MM-DD',
          suffixIcon: enabled ? const Icon(Icons.calendar_today, color: AppColors.gold, size: 18) : null,
          labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(color: enabled ? AppColors.text : AppColors.text2, fontSize: 13),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
        ),
      ),
    );
  }

  Widget _dropdownField(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          filled: true, fillColor: AppColors.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        ),
        items: options.map((o) => DropdownMenuItem<String>(value: o, child: Text(o, style: const TextStyle(color: AppColors.text, fontSize: 13)))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          Switch(
            value: value,
            activeTrackColor: AppColors.gold.withValues(alpha: 0.4),
            activeThumbColor: AppColors.gold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('车辆照片', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ..._photos.map((path) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    ApiConfig.fileUrl(path),
                    width: 80, height: 80, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppColors.border, child: const Icon(Icons.broken_image, color: AppColors.text2, size: 24)),
                  ),
                ),
                Positioned(
                  top: 0, right: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _photos.remove(path)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(2)),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )),
            _photoBtn(Icons.camera_alt, '拍照', () => _pickPhoto(ImageSource.camera)),
            _photoBtn(Icons.photo_library, '相册', () => _pickPhoto(ImageSource.gallery)),
          ]),
        ],
      ),
    );
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
