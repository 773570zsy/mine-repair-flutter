import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/attendance.dart';
import '../../models/vehicle_archive.dart';
import '../../providers/inspection_provider.dart';
import '../../services/vehicle_archive_service.dart';

import '../../config/color_constants.dart';

/// 考勤符号（和 Web 版一致）
const _attSymbols = ['', 'X', 'Y', 'Z', 'V', 'G', '△', '△X', '△Y', '△Z', '△V'];

class AttendancePage extends ConsumerStatefulWidget {
  final bool isOvertime;
  const AttendancePage({super.key, this.isOvertime = false});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  // 考勤模式
  String _symbol = '';
  // 加班模式
  final _otStartCtrl = TextEditingController();
  final _otEndCtrl = TextEditingController();
  final _otLocationCtrl = TextEditingController();
  String? _vehicleType;
  String? _plateNumber;
  List<VehicleArchive> _vehicles = [];
  bool _submitting = false;
  bool _loaded = false;

  // 历史记录月份
  late String _historyMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _historyMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) { _loadToday(); _loadVehicles(); });
  }

  Future<void> _loadToday() async {
    try {
      final att = await ref.read(inspectionServiceProvider).getTodayAttendance();
      if (att != null && mounted && !_loaded) {
        setState(() {
          _loaded = true;
          _symbol = att.attendanceSymbol ?? '';
          if (att.hasOvertime) {
            _otStartCtrl.text = att.overtimeStart ?? '';
            _otEndCtrl.text = att.overtimeEnd ?? '';
            _otLocationCtrl.text = att.overtimeLocation ?? '';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadVehicles() async {
    try {
      final list = await VehicleArchiveService().getList();
      if (mounted) setState(() => _vehicles = list);
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(inspectionActionsProvider.notifier).submitAttendance(
        attendanceSymbol: widget.isOvertime ? null : _symbol,
        overtimeStart: widget.isOvertime ? _otStartCtrl.text : null,
        overtimeEnd: widget.isOvertime ? _otEndCtrl.text : null,
        overtimeLocation: widget.isOvertime ? _otLocationCtrl.text : null,
        vehicleType: widget.isOvertime ? _vehicleType : null,
        plateNumber: widget.isOvertime ? _plateNumber : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isOvertime ? '加班提交成功' : '考勤提交成功')),
        );
        // 刷新历史记录
        ref.invalidate(myAttendanceHistoryProvider(_historyMonth));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _otStartCtrl.dispose(); _otEndCtrl.dispose(); _otLocationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isOvertime ? '今日加班' : '今日考勤';
    final historyAsync = ref.watch(myAttendanceHistoryProvider(_historyMonth));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: FittedBox(fit: BoxFit.scaleDown, child: Text(title)), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ===== 今日提交表单 =====
          widget.isOvertime ? _buildOvertimeForm() : _buildAttendanceForm(),

          const SizedBox(height: 24),

          // ===== 历史记录 =====
          _buildHistorySection(historyAsync),
        ]),
      ),
    );
  }

  // ==================== 考勤表单 ====================

  Widget _buildAttendanceForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('考勤符号', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _symbol,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text, fontSize: 14),
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            ),
            hint: const Text('请选择', style: TextStyle(color: AppColors.text2)),
            items: _attSymbols.map((s) => DropdownMenuItem<String>(
              value: s,
              child: Text(s.isEmpty ? '请选择' : s, style: const TextStyle(color: AppColors.text, fontSize: 14)),
            )).toList(),
            onChanged: (v) => setState(() => _symbol = v ?? ''),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_submitting ? '提交中...' : '提交考勤', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  // ==================== 加班表单 ====================

  Widget _buildOvertimeForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('加班时间', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _timeField('开始', _otStartCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _timeField('结束', _otEndCtrl)),
          ]),
          const SizedBox(height: 8),
          // 车辆类型下拉
          const Text('车辆类型', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _vehicleType,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            ),
            hint: const Text('请选择车辆类型', style: TextStyle(color: AppColors.text2, fontSize: 13)),
            items: () {
              final types = _vehicles.map((v) => v.vehicleType ?? '').where((t) => t.isNotEmpty).toSet().toList()..sort();
              return types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: AppColors.text, fontSize: 13)))).toList();
            }(),
            onChanged: (v) => setState(() { _vehicleType = v; _plateNumber = null; }),
          ),
          const SizedBox(height: 8),
          // 车辆编号下拉（按所选类型过滤）
          const Text('车辆编号', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _plateNumber,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            ),
            hint: const Text('请选择车辆编号', style: TextStyle(color: AppColors.text2, fontSize: 13)),
            items: () {
              var filtered = _vehicles;
              if (_vehicleType != null && _vehicleType!.isNotEmpty) {
                filtered = _vehicles.where((v) => v.vehicleType == _vehicleType).toList();
              }
              return filtered.map((v) => DropdownMenuItem(value: v.plateNumber, child: Text(v.plateNumber, style: const TextStyle(color: AppColors.text, fontSize: 13)))).toList();
            }(),
            onChanged: (v) => setState(() => _plateNumber = v),
          ),
          const SizedBox(height: 8),
          _buildField2('加班地点', _otLocationCtrl, hint: '如：矿区A区'),
        ]),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_submitting ? '提交中...' : '提交加班', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  // ==================== 历史记录 ====================

  Widget _buildHistorySection(AsyncValue<List<AttendanceRecord>> historyAsync) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 标题行 + 月份切换
      Row(children: [
        const Icon(Icons.history, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        const Text('历史记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const Spacer(),
        // 月份切换
        GestureDetector(
          onTap: () => _pickHistoryMonth(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_historyMonth, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.text2),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),

      // 数据区域
      historyAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
        ),
        error: (e, _) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
        data: (records) {
          if (records.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: const Center(child: Text('暂无记录', style: TextStyle(color: AppColors.text2, fontSize: 13))),
            );
          }

          // 按日期倒序（最新在前）
          final sorted = List<AttendanceRecord>.from(records)
            ..sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));

          return Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              // 表头
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                color: AppColors.surface2,
                child: Row(children: [
                  const Expanded(flex: 3, child: Text('日期', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600))),
                  if (widget.isOvertime) ...[
                    const Expanded(flex: 4, child: Text('加班时段', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                    const Expanded(flex: 2, child: Text('小时', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                    const Expanded(flex: 3, child: Text('地点', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  ] else ...[
                    const Expanded(flex: 2, child: Text('考勤', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  ],
                ]),
              ),
              // 数据行
              ...sorted.asMap().entries.map((e) {
                final r = e.value;
                final isToday = r.attendanceDate == _todayStr();
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.gold.withValues(alpha: 0.06) : null,
                    border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
                  ),
                  child: Row(children: [
                    // 日期
                    Expanded(
                      flex: 3,
                      child: Row(children: [
                        Text(
                          r.attendanceDate.length >= 10 ? r.attendanceDate.substring(5) : r.attendanceDate,
                          style: TextStyle(fontSize: 11, color: isToday ? AppColors.gold : AppColors.text, fontWeight: isToday ? FontWeight.w600 : FontWeight.normal),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                            child: const Text('今天', style: TextStyle(fontSize: 8, color: AppColors.gold, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                    ),
                    if (widget.isOvertime) ...[
                      // 加班时段
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: Text(
                            r.hasOvertime ? '${r.overtimeStart ?? ''} → ${r.overtimeEnd ?? ''}' : '-',
                            style: TextStyle(fontSize: 10, color: r.hasOvertime ? AppColors.warning : AppColors.text2),
                          ),
                        ),
                      ),
                      // 小时
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            r.hasOvertime ? '${r.overtimeHours}h' : '-',
                            style: TextStyle(fontSize: 11, color: r.hasOvertime ? AppColors.warning : AppColors.text2, fontWeight: r.hasOvertime ? FontWeight.w600 : FontWeight.normal),
                          ),
                        ),
                      ),
                      // 地点
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            (r.overtimeLocation ?? '').isNotEmpty ? r.overtimeLocation! : '-',
                            style: const TextStyle(fontSize: 10, color: AppColors.text2),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ] else ...[
                      // 考勤符号
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _symbolColor(r.attendanceSymbol ?? '').withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: _symbolColor(r.attendanceSymbol ?? '').withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              r.attendanceSymbol ?? '-',
                              style: TextStyle(fontSize: 11, color: _symbolColor(r.attendanceSymbol ?? ''), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                );
              }),
            ]),
          );
        },
      ),
    ]);
  }

  // ==================== 辅助方法 ====================

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Color _symbolColor(String symbol) {
    if (symbol.isEmpty || symbol == '-') return AppColors.text2;
    if (symbol.contains('△')) return AppColors.warning;
    return AppColors.gold;
  }

  Future<void> _pickHistoryMonth() async {
    final parts = _historyMonth.split('-');
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(int.tryParse(parts[0]) ?? DateTime.now().year, int.tryParse(parts[1]) ?? DateTime.now().month),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: AppColors.bg, surface: AppColors.surface)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _historyMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
    }
  }

  void _pickTime(TextEditingController ctrl) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (_, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _timeField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      onTap: () => _pickTime(ctrl),
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, hintText: 'HH:MM',
        suffixIcon: const Icon(Icons.access_time, color: AppColors.gold, size: 18),
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
        hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
        filled: true, fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }

  Widget _buildField2(String label, TextEditingController ctrl, {String? hint}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
        filled: true, fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }
}
