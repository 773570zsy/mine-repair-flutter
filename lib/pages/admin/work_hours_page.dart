import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/color_constants.dart';
import '../../models/inspection.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../services/download_service.dart';

/// 员工作业工时记录与导出
/// 数据来源：早晚检记录 → 统计驾驶员每天开的车、工时、公里数、加油量
class WorkHoursPage extends ConsumerStatefulWidget {
  const WorkHoursPage({super.key});

  @override
  ConsumerState<WorkHoursPage> createState() => _WorkHoursPageState();
}

class _WorkHoursPageState extends ConsumerState<WorkHoursPage> {
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
    final params = WorkHoursParams(month: _month, driverId: _driverId, departmentId: _departmentId);
    final reportAsync = ref.watch(workHoursProvider(params));
    final driversAsync = ref.watch(driverListProvider);
    final departmentsAsync = ref.watch(departmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text('员工作业工时')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          // 导出工时统计 Excel
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 20, color: AppColors.gold),
            tooltip: '导出工时统计',
            onPressed: () => _exportWorkHours(),
          ),
        ],
      ),
      body: Column(children: [
        // ===== 筛选栏 =====
        _buildFilterBar(driversAsync, departmentsAsync),
        const Divider(color: AppColors.border, height: 1),
        // ===== 数据区域 =====
        Expanded(child: reportAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (data) {
            final summaries = (data['summary'] as List<dynamic>?)
                ?.map((s) => WorkHoursSummary.fromJson(s as Map<String, dynamic>))
                .toList() ?? [];

            if (summaries.isEmpty) {
              return const Center(child: Text('暂无作业记录', style: TextStyle(color: AppColors.text2)));
            }

            // ===== 月度总览卡片 =====
            final totalHours = summaries.fold<double>(0, (s, i) => s + i.totalHours);
            final totalKm = summaries.fold<double>(0, (s, i) => s + i.totalKm);
            final totalFuel = summaries.fold<double>(0, (s, i) => s + i.totalFuel);
            final totalDays = summaries.fold<int>(0, (s, i) => s + i.days);

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: summaries.length + 1, // +1 for summary header
              itemBuilder: (_, i) {
                if (i == 0) return _buildMonthSummary(totalHours, totalKm, totalFuel, totalDays, summaries.length);
                return _driverCard(summaries[i - 1]);
              },
            );
          },
        )),
      ]),
    );
  }

  // ===== 筛选栏 =====
  Widget _buildFilterBar(AsyncValue<List<AdminUser>> driversAsync, AsyncValue<List<Department>> departmentsAsync) {
    return Container(
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
            error: (_, __) => Container(height: 36, alignment: Alignment.center, child: const Text('加载失败', style: TextStyle(color: AppColors.text2, fontSize: 12))),
            data: (depts) => _deptDropdown(depts),
          ),
        ),
        const SizedBox(width: 8),
        // 驾驶员筛选
        Expanded(
          child: driversAsync.when(
            loading: () => Container(height: 36, alignment: Alignment.center, child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
            error: (_, __) => Container(height: 36, alignment: Alignment.center, child: const Text('加载失败', style: TextStyle(color: AppColors.text2, fontSize: 12))),
            data: (drivers) => _driverDropdown(drivers),
          ),
        ),
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

  // ===== 月度总览 =====
  Widget _buildMonthSummary(double hours, double km, double fuel, int days, int driverCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gold.withValues(alpha: 0.12), AppColors.surface.withValues(alpha: 0.8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics_outlined, size: 16, color: AppColors.gold),
          const SizedBox(width: 6),
          Text('$_month 月度总览', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _summaryTile('驾驶员', '$driverCount人'),
          _summaryTile('出勤天数', '$days天'),
          _summaryTile('总工时', '${hours.toStringAsFixed(1)}h', color: AppColors.info),
          _summaryTile('总公里', '${km.toStringAsFixed(1)}km', color: AppColors.gold),
          _summaryTile('总加油', '${fuel.toStringAsFixed(1)}L', color: AppColors.warning),
        ]),
      ]),
    );
  }

  Widget _summaryTile(String label, String value, {Color color = AppColors.text}) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text2)),
      ]),
    );
  }

  // ===== 驾驶员卡片（可折叠） =====
  Widget _driverCard(WorkHoursSummary s) {
    final records = s.records.map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r as Map)).toList();

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
            child: Center(child: Text(s.driverName.isNotEmpty ? s.driverName[0] : '?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.driverName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 1),
              Text('${s.days}天出勤', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]),
          ),
          // 工时
          _badge('${s.totalHours.toStringAsFixed(1)}h', AppColors.info),
          const SizedBox(width: 6),
          // 公里
          _badge('${s.totalKm.toStringAsFixed(1)}km', AppColors.gold),
          const SizedBox(width: 6),
          // 加油
          if (s.totalFuel > 0)
            _badge('${s.totalFuel.toStringAsFixed(1)}L', AppColors.warning),
        ]),
        // 展开后的明细
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 4),
          // 明细表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(4)),
            child: const Row(children: [
              Expanded(flex: 2, child: _TH('日期')),
              Expanded(flex: 3, child: _TH('车辆')),
              Expanded(flex: 3, child: _TH('工时(上班→下班=作业)')),
              Expanded(flex: 3, child: _TH('公里(上班→下班=行驶)')),
              Expanded(flex: 1, child: _TH('加油')),
            ]),
          ),
          const SizedBox(height: 2),
          ...records.map((r) => _detailRow(r)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ===== 明细行 =====
  Widget _detailRow(Map<String, dynamic> r) {
    final date = (r['inspection_date'] ?? '') as String;
    final plate = (r['plate_number'] ?? '-') as String;
    final vehicleType = (r['vehicle_type'] ?? '') as String;
    final startHours = (r['start_hours'] as num?)?.toDouble() ?? 0;
    final endHours = (r['end_hours'] as num?)?.toDouble() ?? 0;
    final workHours = (r['work_hours'] as num?)?.toDouble() ?? 0;
    final startKm = (r['start_km'] as num?)?.toDouble() ?? 0;
    final endKm = (r['end_km'] as num?)?.toDouble() ?? 0;
    final drivenKm = (r['driven_km'] as num?)?.toDouble() ?? 0;
    final fuel = (r['fuel_amount'] as num?)?.toDouble() ?? 0;

    final displayDate = date.length >= 10 ? date.substring(5) : date;
    final vehLabel = vehicleType.isNotEmpty ? '$plate ($vehicleType)' : plate;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.2))),
      ),
      child: Row(children: [
        // 日期
        Expanded(flex: 2, child: Text(displayDate, style: const TextStyle(fontSize: 11, color: AppColors.text))),
        // 车辆
        Expanded(flex: 3, child: Text(vehLabel, style: const TextStyle(fontSize: 10, color: AppColors.text), overflow: TextOverflow.ellipsis)),
        // 工时
        Expanded(
          flex: 3,
          child: Center(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${startHours.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                const TextSpan(text: '→', style: TextStyle(fontSize: 10, color: AppColors.text2)),
                TextSpan(text: '${endHours.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                TextSpan(text: '=${workHours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 10, color: workHours > 0 ? AppColors.info : AppColors.text2, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        // 公里
        Expanded(
          flex: 3,
          child: Center(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${startKm.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                const TextSpan(text: '→', style: TextStyle(fontSize: 10, color: AppColors.text2)),
                TextSpan(text: '${endKm.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                TextSpan(text: '=${drivenKm.toStringAsFixed(1)}km', style: TextStyle(fontSize: 10, color: drivenKm > 0 ? AppColors.gold : AppColors.text2, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        // 加油
        Expanded(
          flex: 1,
          child: Center(
            child: Text(fuel > 0 ? '${fuel.toStringAsFixed(1)}L' : '-', style: TextStyle(fontSize: 10, color: fuel > 0 ? AppColors.warning : AppColors.text2, fontWeight: fuel > 0 ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      ]),
    );
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

  // ===== 导出工时统计 =====
  Future<void> _exportWorkHours() async {
    try {
      _snack('正在生成工时统计表...');
      final path = await DownloadService.instance.downloadXlsx(
        '/inspection/export-workhours-xlsx',
        {
          'month': _month,
          if (_driverId != null) 'driver_id': _driverId,
          if (_departmentId != null) 'department_id': _departmentId,
        },
        '员工工时统计_$_month.xlsx',
      );
      if (mounted) _snack(path != null ? '已保存: $path' : '导出成功，请检查浏览器下载');
    } catch (e) {
      if (mounted) _snack('导出失败: $e');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
}

/// 表头文字
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 9, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: TextAlign.center);
  }
}
