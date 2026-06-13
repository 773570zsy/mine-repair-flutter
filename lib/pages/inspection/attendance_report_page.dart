import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/color_constants.dart';
import '../../models/attendance.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../services/download_service.dart';

class AttendanceReportPage extends ConsumerStatefulWidget {
  const AttendanceReportPage({super.key});

  @override
  ConsumerState<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends ConsumerState<AttendanceReportPage> {
  String _month = '';
  int? _driverId;
  int? _departmentId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final params = AttendanceReportParams(month: _month, driverId: _driverId, departmentId: _departmentId);
    final reportAsync = ref.watch(attendanceReportProvider(params));
    // Load drivers and departments for filter dropdowns
    final driversAsync = ref.watch(driverListProvider);
    final departmentsAsync = ref.watch(departmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('员工出勤'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          // 考勤导出
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.gold),
            tooltip: '导出考勤表',
            onPressed: () => _exportAttendance(),
          ),
          // 加班导出
          IconButton(
            icon: const Icon(Icons.more_time_outlined, size: 20, color: AppColors.warning),
            tooltip: '导出加班记录',
            onPressed: () => _exportOvertime(),
          ),
        ],
      ),
      body: Column(children: [
        // ===== 筛选栏 =====
        Container(
          padding: const EdgeInsets.all(10),
          color: AppColors.surface,
          child: Row(children: [
            // 月份选择
            Expanded(
              child: GestureDetector(
                onTap: () => _pickMonth(context),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Flexible(child: Text(_month, style: const TextStyle(color: AppColors.text, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.text2),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 归属部门筛选
            Expanded(
              child: departmentsAsync.when(
                loading: () => Container(height: 36, alignment: Alignment.center, child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
                error: (_, _) => Container(height: 36, alignment: Alignment.center, child: const Text('加载失败', style: TextStyle(color: AppColors.text2, fontSize: 12))),
                data: (depts) => _deptDropdown(depts),
              ),
            ),
            const SizedBox(width: 8),
            // 驾驶员筛选
            Expanded(
              child: driversAsync.when(
                loading: () => Container(height: 36, alignment: Alignment.center, child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
                error: (_, _) => Container(height: 36, alignment: Alignment.center, child: const Text('加载失败', style: TextStyle(color: AppColors.text2, fontSize: 12))),
                data: (drivers) => _driverDropdown(drivers),
              ),
            ),
          ]),

        ),
        const Divider(color: AppColors.border, height: 1),
        // ===== 数据区域 =====
        Expanded(child: reportAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (records) {
            if (records.isEmpty) {
              return const Center(child: Text('暂无考勤记录', style: TextStyle(color: AppColors.text2)));
            }
            // 按驾驶员分组
            final grouped = <String, List<AttendanceRecord>>{};
            for (final r in records) {
              final name = r.driverName ?? '未知';
              grouped.putIfAbsent(name, () => []).add(r);
            }
            // 按姓名排序
            final names = grouped.keys.toList()..sort();

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: names.length,
              itemBuilder: (_, i) => _driverCard(names[i], grouped[names[i]]!),
            );
          },
        )),
      ]),
    );
  }

  // ===== 驾驶员下拉 =====
  Widget _driverDropdown(List<AdminUser> drivers) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _driverId,
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('全部驾驶员', style: TextStyle(color: AppColors.text2, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ...drivers.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name, style: const TextStyle(color: AppColors.text, fontSize: 13), overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => _driverId = v),
          dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 20),
          isDense: true,
        ),
      ),
    );
  }

  // ===== 部门下拉 =====
  Widget _deptDropdown(List<Department> depts) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _departmentId,
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('全部归属部门', style: TextStyle(color: AppColors.text2, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ...depts.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name, style: const TextStyle(color: AppColors.text, fontSize: 13), overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => _departmentId = v),
          dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 20),
          isDense: true,
        ),
      ),
    );
  }

  // ===== 驾驶员卡片（可折叠） =====
  Widget _driverCard(String name, List<AttendanceRecord> items) {
    final overtimeTotal = items.fold<double>(0, (sum, r) => sum + r.overtimeHours);
    final overtimeDays = items.where((r) => r.hasOvertime).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.text2,
        collapsedIconColor: AppColors.text2,
        // 折叠时的摘要行
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(17)),
            child: Center(child: Text(name[0], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 1),
              Text('${items.length}天出勤', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]),
          ),
          // 加班汇总
          if (overtimeTotal > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.more_time_outlined, size: 12, color: AppColors.warning),
                const SizedBox(width: 3),
                Text('${overtimeDays}天 ${overtimeTotal}h', style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        // 展开后的明细
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 4),
          // 明细表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(4)),
            child: const Row(children: [
              Expanded(flex: 2, child: Text('日期', style: TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('考勤', style: TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(flex: 3, child: Text('加班时段', style: TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text('小时', style: TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('地点', style: TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text('编号', style: TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('车型', style: TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
            ]),
          ),
          const SizedBox(height: 2),
          ...items.map((r) => _detailRow(r)),
        ],
      ),
    );
  }

  // ===== 明细行 =====
  Widget _detailRow(AttendanceRecord r) {
    final hasOT = r.hasOvertime;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.2))),
      ),
      child: Row(children: [
        // 日期（显示 MM-DD）
        Expanded(
          flex: 2,
          child: Text(r.attendanceDate.length >= 10 ? r.attendanceDate.substring(5) : r.attendanceDate, style: const TextStyle(fontSize: 11, color: AppColors.text)),
        ),
        // 考勤符号
        Expanded(
          flex: 1,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _symbolColor(r.attendanceSymbol ?? '').withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _symbolColor(r.attendanceSymbol ?? '').withValues(alpha: 0.3)),
              ),
              child: Text(r.attendanceSymbol ?? '-', style: TextStyle(fontSize: 11, color: _symbolColor(r.attendanceSymbol ?? ''), fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        // 加班时段
        Expanded(
          flex: 3,
          child: Center(
            child: Text(hasOT ? '${r.overtimeStart ?? ''} → ${r.overtimeEnd ?? ''}' : '-', style: TextStyle(fontSize: 10, color: hasOT ? AppColors.warning : AppColors.text2)),
          ),
        ),
        // 小时
        Expanded(
          flex: 1,
          child: Center(
            child: Text(hasOT ? '${r.overtimeHours}h' : '-', style: TextStyle(fontSize: 11, color: hasOT ? AppColors.warning : AppColors.text2, fontWeight: hasOT ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
        // 地点
        Expanded(
          flex: 2,
          child: Center(
            child: Text((r.overtimeLocation ?? '').isNotEmpty ? r.overtimeLocation! : '-', style: const TextStyle(fontSize: 10, color: AppColors.text2), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
        ),
        // 车辆编号
        Expanded(
          flex: 1,
          child: Center(
            child: Text((r.plateNumber ?? '').isNotEmpty ? r.plateNumber! : '-', style: const TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ),
        ),
        // 车型
        Expanded(
          flex: 2,
          child: Center(
            child: Text((r.vehicleType ?? '').isNotEmpty ? r.vehicleType! : '-', style: const TextStyle(fontSize: 10, color: AppColors.text2), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }

  Color _symbolColor(String symbol) {
    if (symbol.isEmpty || symbol == '-') return AppColors.text2;
    if (symbol.contains('△')) return AppColors.warning;
    return AppColors.gold;
  }

  // ===== 月份选择 =====
  Future<void> _pickMonth(BuildContext ctx) async {
    final parts = _month.split('-');
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime(int.tryParse(parts[0]) ?? DateTime.now().year, int.tryParse(parts[1]) ?? DateTime.now().month),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: AppColors.bg, surface: AppColors.surface)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _month = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
    }
  }

  // ===== 考勤导出（日历横排格式：姓名 | 1 | 2 | ... | 31） =====
  Future<void> _exportAttendance() async {
    try {
      _snack('正在生成考勤表...');
      final path = await DownloadService.instance.downloadXlsx(
        '/inspection/export-attendance-xlsx',
        {
          'month': _month,
          if (_driverId != null) 'driver_id': _driverId,
          if (_departmentId != null) 'department_id': _departmentId,
        },
        '考勤表_$_month.xlsx',
      );
      if (mounted) _snack(path != null ? '已保存: $path' : '导出成功，请检查浏览器下载');
    } catch (e) {
      if (mounted) _snack('导出失败: $e');
    }
  }

  // ===== 加班导出 =====
  Future<void> _exportOvertime() async {
    try {
      _snack('正在生成加班记录...');
      final path = await DownloadService.instance.downloadXlsx(
        '/inspection/export-overtime-xlsx',
        {
          'month': _month,
          if (_driverId != null) 'driver_id': _driverId,
          if (_departmentId != null) 'department_id': _departmentId,
        },
        '加班记录_$_month.xlsx',
      );
      if (mounted) _snack(path != null ? '已保存: $path' : '导出成功，请检查浏览器下载');
    } catch (e) {
      if (mounted) _snack('导出失败: $e');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
}
