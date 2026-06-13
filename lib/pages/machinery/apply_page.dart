import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/color_constants.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/machinery_provider.dart';
import '../../providers/repair_provider.dart';
import '../../services/http_client.dart';

class ApplyPage extends ConsumerStatefulWidget {
  const ApplyPage({super.key});

  @override
  ConsumerState<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends ConsumerState<ApplyPage> {
  final _deptCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _altitudeCtrl = TextEditingController();

  String _vehicleType = '';
  String _appType = 'short_term';
  String _urgency = 'normal';
  bool _isHazardous = false;
  bool _onsiteBriefing = false;
  final _remarkCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  final List<String> _photos = [];
  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillUser());
  }

  void _prefillUser() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone;
      if (user.deptName != null) _deptCtrl.text = user.deptName!;
    }
  }

  @override
  void dispose() {
    _deptCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _purposeCtrl.dispose();
    _locationCtrl.dispose();
    _altitudeCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  // ---- 照片 ----
  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      _upload(bytes, xfile.name);
    }
  }

  Future<void> _upload(Uint8List bytes, String filename) async {
    try {
      final resp = await HttpClient().uploadBytes('/upload/single', bytes, filename, 'file');
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? resp.data as Map : null;
        final url = data?['url']?.toString() ?? data?['path']?.toString() ?? '';
        if (url.isNotEmpty) setState(() => _photos.add(url));
      }
    } catch (e) {
      if (mounted) _snack('上传失败: $e');
    }
  }

  // ---- 日期/时间选择（中文） ----
  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('zh'),
      initialDate: isStart && _startDate != null ? _startDate! : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (_, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold)), child: child!),
    );
    if (picked != null) setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (_, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  String _fmt(DateTime? d) => d != null ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' : '';
  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ---- 提交 ----
  Future<void> _submit() async {
    if (_deptCtrl.text.trim().isEmpty) return _snack('请填写申请部门');
    if (_nameCtrl.text.trim().isEmpty) return _snack('请填写申请人姓名');
    if (_phoneCtrl.text.trim().isEmpty) return _snack('请填写申请人电话');
    if (_startDate == null) return _snack('请选择开始日期');
    if (_endDate == null) return _snack('请选择结束日期');
    if (_vehicleType.isEmpty) return _snack('请选择车辆类型');
    if (_purposeCtrl.text.trim().isEmpty) return _snack('请填写作业用途');
    if (_locationCtrl.text.trim().isEmpty) return _snack('请填写作业地点');
    if (_startDate!.isAfter(_endDate!)) return _snack('开始日期不能晚于结束日期');

    setState(() => _submitting = true);
    try {
      await ref.read(machineryActionsProvider).submitApplication(
        applicantDept: _deptCtrl.text.trim(),
        applicantName: _nameCtrl.text.trim(),
        applicantPhone: _phoneCtrl.text.trim(),
        vehicleType: _vehicleType,
        applicationType: _appType,
        scheduledStart: '${_fmt(_startDate)} ${_fmtTime(_startTime)}',
        scheduledEnd: '${_fmt(_endDate)} ${_fmtTime(_endTime)}',
        workLocation: _locationCtrl.text.trim(),
        workAltitude: _altitudeCtrl.text.trim(),
        workPurpose: _purposeCtrl.text.trim(),
        isHazardous: _isHazardous,
        urgency: _urgency,
        briefingMethod: _onsiteBriefing ? '现场交底' : _remarkCtrl.text.trim(),
        briefingFiles: _photos,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('申请已提交')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ---- UI ----
  static const _labelStyle = TextStyle(color: AppColors.text2, fontSize: 13);
  static const _inputDeco = InputDecoration(
    filled: true, fillColor: AppColors.surface,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.gold)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('用车申请'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 信息头
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.engineering_outlined, color: AppColors.gold, size: 22)),
              const SizedBox(width: 12),
              const Expanded(child: Text('请填写用车申请信息', style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 16),

          // 申请人信息
          _section('申请人信息', Icons.person_outline),
          _field('申请部门 *', _deptCtrl, hint: '自动填入所属部门'),
          _field('申请人姓名 *', _nameCtrl, hint: '自动填入登录账号'),
          _field('申请人电话 *', _phoneCtrl, hint: '自动填入登录账号'),
          const SizedBox(height: 20),

          // 车辆需求
          _section('车辆需求', Icons.directions_car_outlined),
          _vehicleTypeDropdown(),
          Row(children: [
            Expanded(child: _dropdown('申请类型', _appType, {'short_term': '短期用车', 'long_term': '长期用车'}, (v) => setState(() => _appType = v!))),
            const SizedBox(width: 10),
            Expanded(child: _dropdown('紧急程度', _urgency, {'normal': '普通', 'urgent': '加急', 'emergency': '紧急'}, (v) => setState(() => _urgency = v!))),
          ]),
          const SizedBox(height: 20),

          // 时间
          _section('用车时间', Icons.schedule_outlined),
          Row(children: [
            Expanded(child: _dateBtn('开始日期', _startDate, () => _pickDate(true))),
            const SizedBox(width: 8),
            Expanded(child: _timeBtn('开始时间', _startTime, () => _pickTime(true))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _dateBtn('结束日期', _endDate, () => _pickDate(false))),
            const SizedBox(width: 8),
            Expanded(child: _timeBtn('结束时间', _endTime, () => _pickTime(false))),
          ]),
          const SizedBox(height: 20),

          // 作业信息
          _section('作业信息', Icons.construction_outlined),
          _field('作业用途 *', _purposeCtrl, hint: '如：挖掘基坑'),
          _field('作业地点 *', _locationCtrl, hint: '如：矿区A区'),
          _field('作业点海拔', _altitudeCtrl, hint: '如：3500m'),
          _switchTile(Icons.warning_amber_outlined, '是否涉及危险作业', _isHazardous, (v) => setState(() => _isHazardous = v)),
          _switchTile(Icons.record_voice_over_outlined, '是否现场交底', _onsiteBriefing, (v) => setState(() => _onsiteBriefing = v)),
          if (!_onsiteBriefing) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _field('备注', _remarkCtrl, hint: '如：电话交底/视频交底'),
            ),
            const SizedBox(height: 20),
            _section('交底资料（选填）', Icons.attach_file_outlined),
            _photoSection(),
          ],
          const SizedBox(height: 20),

          // 提交
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg)) : const Icon(Icons.send_outlined, size: 18),
              label: Text(_submitting ? '提交中...' : '提交申请', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ---- 组件 ----
  Widget _section(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl, maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          labelStyle: _labelStyle,
          hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
          prefixIcon: Icon(_fieldIcon(label), color: AppColors.text2, size: 18),
          filled: true, fillColor: AppColors.surface,
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.gold)),
        ),
      ),
    );
  }

  IconData _fieldIcon(String label) {
    if (label.contains('部门')) return Icons.business_outlined;
    if (label.contains('姓名')) return Icons.badge_outlined;
    if (label.contains('电话')) return Icons.phone_outlined;
    if (label.contains('用途')) return Icons.assignment_outlined;
    if (label.contains('地点')) return Icons.location_on_outlined;
    if (label.contains('海拔')) return Icons.terrain_outlined;
    if (label.contains('交底')) return Icons.menu_book_outlined;
    return Icons.edit_outlined;
  }

  Widget _vehicleTypeDropdown() {
    final vehicles = ref.watch(vehicleListProvider).valueOrNull ?? [];
    final types = vehicles.map((v) => v.vehicleType).where((t) => t != null && t.isNotEmpty).toSet().toList()..sort();
    if (types.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('车辆类型 *', style: _labelStyle),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.warning),
              SizedBox(width: 8),
              Text('暂无车辆档案，请先到车辆档案录入', style: TextStyle(color: AppColors.warning, fontSize: 13)),
            ]),
          ),
        ]),
      );
    }
    return _dropdown('车辆类型 *', _vehicleType, Map.fromEntries(types.map((t) => MapEntry(t, t))), (v) {
      setState(() => _vehicleType = v!);
    });
  }

Widget _dropdown(String label, String value, Map<String, String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.isEmpty ? null : value,
              isExpanded: true,
              hint: Text('请选择', style: const TextStyle(color: AppColors.text2, fontSize: 14)),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2),
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              dropdownColor: AppColors.surface,
              items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _switchTile(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      secondary: Icon(icon, color: value ? AppColors.warning : AppColors.text2, size: 20),
      title: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 14)),
      value: value,
      activeColor: AppColors.warning,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _dateBtn(String label, DateTime? value, VoidCallback onTap) {
    final hasVal = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: hasVal ? AppColors.gold : AppColors.border)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, color: hasVal ? AppColors.gold : AppColors.text2, size: 18),
          const SizedBox(width: 8),
          Text(hasVal ? _fmt(value) : label, style: TextStyle(fontSize: 14, color: hasVal ? AppColors.text : AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _timeBtn(String label, TimeOfDay value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.gold.withValues(alpha: 0.5))),
        child: Row(children: [
          Icon(Icons.access_time_outlined, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(_fmtTime(value), style: const TextStyle(fontSize: 14, color: AppColors.text)),
        ]),
      ),
    );
  }

  Widget _photoSection() {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ..._photos.asMap().entries.map((e) => Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(ApiConfig.fileUrl(e.value), width: 80, height: 80, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppColors.border, child: const Icon(Icons.broken_image_outlined, color: AppColors.text2)),
          ),
        ),
        Positioned(top: 0, right: 0, child: GestureDetector(
          onTap: () => setState(() => _photos.removeAt(e.key)),
          child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(2)), child: const Icon(Icons.close, size: 14, color: Colors.white)),
        )),
      ])),
      _photoBtn(Icons.camera_alt_outlined, '拍照', () => _pickPhoto(ImageSource.camera)),
      _photoBtn(Icons.photo_library_outlined, '相册', () => _pickPhoto(ImageSource.gallery)),
    ]);
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 10)),
        ]),
      ),
    );
  }
}
