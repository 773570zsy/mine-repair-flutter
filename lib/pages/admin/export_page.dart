import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/color_constants.dart';
import '../../models/admin.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_archive.dart';
import '../../providers/admin_provider.dart';
import '../../providers/repair_provider.dart';
import '../../providers/vehicle_archive_provider.dart';
import '../../services/download_service.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('维修数据导出'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.text2,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: '维修工单导出'), Tab(text: '维修费用报表')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [_OrdersTab(), _CostTab()],
      ),
    );
  }
}

// ==================== 维修工单导出Tab ====================
class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab();

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  String? _status;
  int? _repairShopId;
  String? _plateNumber;
  String? _vehicleType;
  int? _departmentId;
  String _driverKeyword = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String? get _dateFromStr => _dateFrom?.toIso8601String().split('T')[0];
  String? get _dateToStr => _dateTo?.toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final filter = ExportFilter(
      dateFrom: _dateFromStr, dateTo: _dateToStr, status: _status,
      repairShopId: _repairShopId, plateKeyword: _plateNumber,
      vehicleType: _vehicleType, departmentId: _departmentId,
      driverKeyword: _driverKeyword.isNotEmpty ? _driverKeyword : null,
    );
    final shopsAsync = ref.watch(repairShopsProvider);
    final archivesAsync = ref.watch(vehicleArchiveListProvider);
    final departmentsAsync = ref.watch(departmentsProvider);
    final driversAsync = ref.watch(driverListProvider);
    final ordersAsync = ref.watch(exportOrdersProvider(filter));

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(10), color: AppColors.surface,
        child: Column(children: [
          // 第一行：日期范围 + 状态
          Row(children: [
            Expanded(child: _datePicker('开始', _dateFrom, (d) => setState(() => _dateFrom = d))),
            const SizedBox(width: 8),
            Expanded(child: _datePicker('结束', _dateTo, (d) => setState(() => _dateTo = d))),
            const SizedBox(width: 8),
            Expanded(child: _statusDropdown()),
          ]),
          const SizedBox(height: 8),
          // 第二行：归属部门 + 修理厂 + 车辆编号
          Row(children: [
            Expanded(child: departmentsAsync.when(
              loading: () => _loading(), error: (_, __) => _error(),
              data: (depts) => _deptDropdown(depts))),
            const SizedBox(width: 8),
            Expanded(child: shopsAsync.when(
              loading: () => _loading(), error: (_, __) => _error(),
              data: (shops) => _shopDropdown(shops))),
            const SizedBox(width: 8),
            Expanded(child: archivesAsync.when(
              loading: () => _loading(), error: (_, __) => _error(),
              data: (archives) => _plateDropdown(archives))),
          ]),
          const SizedBox(height: 8),
          // 第三行：车型 + 驾驶员 + 导出
          Row(children: [
            Expanded(child: archivesAsync.when(
              loading: () => _loading(), error: (_, __) => _error(),
              data: (archives) => _vehicleTypeDropdown(archives))),
            const SizedBox(width: 8),
            Expanded(child: driversAsync.when(
              loading: () => _loading(), error: (_, __) => _error(),
              data: (drivers) => _driverDropdown(drivers))),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _export(),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('下载XLSX', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ]),
        ]),
      ),
      Expanded(child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (orders) => orders.isEmpty
            ? const Center(child: Text('暂无工单', style: TextStyle(color: AppColors.text2)))
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('共 ${orders.length} 条', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _orderRow(orders[i]),
                  ),
                ),
              ]),
      )),
    ]);
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime?> onChange) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context, initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030),
          locale: const Locale('zh'),
          builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: AppColors.bg, surface: AppColors.surface),
          ), child: child!),
        );
        if (picked != null) onChange(picked);
      },
      child: Container(
        height: 36, padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 12, color: value != null ? AppColors.gold : AppColors.text2),
          const SizedBox(width: 4),
          Text(value != null ? value.toIso8601String().split('T')[0] : label, style: TextStyle(fontSize: 12, color: value != null ? AppColors.text : AppColors.text2)),
          if (value != null) ...[const Spacer(), GestureDetector(onTap: () => onChange(null), child: const Icon(Icons.close, size: 12, color: AppColors.text2))],
        ]),
      ),
    );
  }

  Widget _statusDropdown() {
    const statuses = {'': '全部状态', 'pending_accept': '待接单', 'pending_quote': '待报价', 'pending_approval': '待审批', 'approved': '已通过', 'repairing': '维修中', 'completed': '待验收', 'accepted': '已完成'};
    return Container(
      height: 36, padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _status, isDense: true, dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 20),
          items: statuses.entries.map((e) => DropdownMenuItem<String?>(value: e.key.isEmpty ? null : e.key, child: Text(e.value, style: const TextStyle(color: AppColors.text, fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _status = v),
        ),
      ),
    );
  }

  Widget _shopDropdown(List<RepairShop> shops) {
    final items = [const DropdownMenuItem<int?>(value: null, child: Text('全部修理厂', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...shops.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _dd<int?>('', _repairShopId, items, (v) => setState(() => _repairShopId = v));
  }
  Widget _plateDropdown(List<VehicleArchive> archives) {
    final plates = archives.map((a) => a.plateNumber).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final items = [const DropdownMenuItem<String?>(value: null, child: Text('全部车辆', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...plates.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _dd<String?>('', _plateNumber, items, (v) => setState(() => _plateNumber = v));
  }
  Widget _vehicleTypeDropdown(List<VehicleArchive> archives) {
    final typeSet = <String>{};
    for (final a in archives) {
      if (a.vehicleType != null && a.vehicleType!.isNotEmpty) {
        typeSet.add(a.vehicleType!);
      }
    }
    final types = typeSet.toList()..sort();
    final items = [const DropdownMenuItem<String?>(value: null, child: Text('全部车型', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...types.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _dd<String?>('', _vehicleType, items, (v) => setState(() => _vehicleType = v));
  }
  Widget _driverDropdown(List<AdminUser> drivers) {
    final items = [const DropdownMenuItem<String?>(value: null, child: Text('全部驾驶员', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...drivers.map((d) => DropdownMenuItem<String?>(value: d.name, child: Text(d.name, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _dd<String?>('', _driverKeyword.isNotEmpty ? _driverKeyword : null, items, (v) => setState(() => _driverKeyword = v ?? ''));
  }
  Widget _dd<T>(String label, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChange) {
    return Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, items: items, onChanged: onChange, dropdownColor: AppColors.surface2, icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 20), isDense: true)));
  }
  Widget _deptDropdown(List<Department> depts) {
    final items = [const DropdownMenuItem<int?>(value: null, child: Text('全部归属部门', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...depts.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _dd<int?>('', _departmentId, items, (v) => setState(() => _departmentId = v));
  }
  Widget _loading() => Container(height: 36, alignment: Alignment.center, child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)));
  Widget _error() => Container(height: 36, alignment: Alignment.center, child: const Text('加载失败', style: TextStyle(color: AppColors.text2, fontSize: 11)));

  Widget _orderRow(dynamic o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.orderNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
          const SizedBox(width: 8),
          Text(o.statusLabel, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ]),
        const SizedBox(height: 2),
        Text('${o.plateNumber} · ${o.driverName ?? "-"} · ${o.deptName ?? "-"}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        Row(children: [
          Text('配件¥${o.partsCost.toStringAsFixed(2)} 人工¥${o.laborCost.toStringAsFixed(2)} 工时¥${o.hoursCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          const Spacer(),
          Text('合计 ¥${o.quoteAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger)),
        ]),
      ]),
    );
  }

  Future<void> _export() async {
    try {
      final path = await DownloadService.instance.downloadXlsx('/admin/export-orders-xlsx', {
        if (_dateFromStr != null) 'date_from': _dateFromStr,
        if (_dateToStr != null) 'date_to': _dateToStr,
        if (_status != null) 'status': _status,
        if (_repairShopId != null) 'repair_shop_id': _repairShopId,
        if (_plateNumber != null) 'plate_keyword': _plateNumber,
        if (_vehicleType != null) 'vehicle_type': _vehicleType,
        if (_departmentId != null) 'department_id': _departmentId,
        if (_driverKeyword.isNotEmpty) 'driver_keyword': _driverKeyword,
      }, '维修工单导出_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx');
      if (mounted) _snack(path != null ? '已保存到 Downloads 文件夹，可在分享面板中发送或保存' : '导出成功');
    } catch (e) { if (mounted) _snack('导出失败: $e'); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 3)));
}

// ==================== 维修费用报表Tab ====================
class _CostTab extends ConsumerStatefulWidget {
  const _CostTab();

  @override
  ConsumerState<_CostTab> createState() => _CostTabState();
}

class _CostTabState extends ConsumerState<_CostTab> {
  String? _deptType;
  int? _repairShopId;
  int? _departmentId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _plateNumber;
  String? _vehicleType;
  String _driverKeyword = '';

  String? get _dateFromStr => _dateFrom?.toIso8601String().split('T')[0];
  String? get _dateToStr => _dateTo?.toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final filter = CostFilter(
      dateFrom: _dateFromStr, dateTo: _dateToStr,
      repairShopId: _repairShopId, departmentId: _departmentId,
      deptType: _deptType, plateKeyword: _plateNumber,
      vehicleType: _vehicleType,
      driverKeyword: _driverKeyword.isNotEmpty ? _driverKeyword : null,
    );
    final shopsAsync = ref.watch(repairShopsProvider);
    final archivesAsync = ref.watch(vehicleArchiveListProvider);
    final departmentsAsync = ref.watch(departmentsProvider);
    final driversAsync = ref.watch(driverListProvider);
    final async = ref.watch(costReportProvider(filter));

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(10), color: AppColors.surface,
        child: Column(children: [
          // 第一行：日期范围 + 维修类型
          Row(children: [
            Expanded(child: _datePicker('开始日期', _dateFrom, (d) => setState(() => _dateFrom = d))),
            const SizedBox(width: 8),
            Expanded(child: _datePicker('结束日期', _dateTo, (d) => setState(() => _dateTo = d))),
            const SizedBox(width: 8),
            Expanded(child: _typeDropdown()),
          ]),
          const SizedBox(height: 8),
          // 第二行：归属部门 + 修理厂 + 车辆编号
          Row(children: [
            Expanded(child: departmentsAsync.when(
              loading: () => _loading(),
              error: (_, __) => _error(),
              data: (depts) => _costDeptDropdown(depts))),
            const SizedBox(width: 8),
            Expanded(child: shopsAsync.when(
              loading: () => _loading(),
              error: (_, __) => _error(),
              data: (shops) => _costShopDropdown(shops))),
            const SizedBox(width: 8),
            Expanded(child: archivesAsync.when(
              loading: () => _loading(),
              error: (_, __) => _error(),
              data: (archives) => _costPlateDropdown(archives))),
          ]),
          const SizedBox(height: 8),
          // 第三行：车型 + 驾驶员 + 导出
          Row(children: [
            Expanded(child: archivesAsync.when(
              loading: () => _loading(),
              error: (_, __) => _error(),
              data: (archives) => _costVehicleTypeDropdown(archives))),
            const SizedBox(width: 8),
            Expanded(child: driversAsync.when(
              loading: () => _loading(),
              error: (_, __) => _error(),
              data: (drivers) => _costDriverDropdown(drivers))),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _export(),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('下载XLSX', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ]),
        ]),
      ),
      Expanded(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (result) {
          final s = result.summary;
          return ListView(padding: const EdgeInsets.all(10), children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                _sumRow('总费用', '¥${s.totalAmount.toStringAsFixed(2)}', AppColors.danger),
                _sumRow('配件费', '¥${s.totalParts.toStringAsFixed(2)}', AppColors.warning),
                _sumRow('人工费', '¥${s.totalLabor.toStringAsFixed(2)}', AppColors.warning),
                _sumRow('工时费', '¥${s.totalHours.toStringAsFixed(2)}', AppColors.warning),
                _sumRow('工单数', '${s.count}', AppColors.text),
              ]),
            ),
            const SizedBox(height: 10),
            if (s.byShop.isNotEmpty) ...[
              _section('按修理厂'),
              ...s.byShop.map((sh) => _subCard(sh.name, '${sh.count}单 · ¥${sh.totalAmount.toStringAsFixed(2)}', AppColors.gold)),
            ],
            if (s.byDept.isNotEmpty) ...[
              const SizedBox(height: 10),
              _section('按部门'),
              ...s.byDept.map((d) => _subCard(d.name, '${d.count}单 · ¥${d.totalAmount.toStringAsFixed(2)}', AppColors.text)),
            ],
            const SizedBox(height: 10),
            _section('明细 (${result.items.length}条)'),
            ...result.items.take(50).map(_itemRow),
          ]);
        },
      )),
    ]);
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime?> onChange) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context, initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('zh'),
          builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: AppColors.bg, surface: AppColors.surface)), child: child!),
        );
        if (picked != null) onChange(picked);
      },
      child: Container(
        height: 36, padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 12, color: value != null ? AppColors.gold : AppColors.text2),
          const SizedBox(width: 4),
          Text(value != null ? value.toIso8601String().split('T')[0] : label, style: TextStyle(fontSize: 12, color: value != null ? AppColors.text : AppColors.text2)),
          if (value != null) ...[const Spacer(), GestureDetector(onTap: () => onChange(null), child: const Icon(Icons.close, size: 12, color: AppColors.text2))],
        ]),
      ),
    );
  }

  Widget _typeDropdown() {
    const types = {'': '全部类型', 'internal': '内部维修', 'external': '外部维修'};
    return _costDd<String?>('', _deptType, types.entries.map((e) => DropdownMenuItem<String?>(value: e.key.isEmpty ? null : e.key, child: Text(e.value, style: const TextStyle(color: AppColors.text, fontSize: 12)))).toList(), (v) => setState(() => _deptType = v));
  }

  Widget _costShopDropdown(List<RepairShop> shops) {
    final items = [const DropdownMenuItem<int?>(value: null, child: Text('全部修理厂', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...shops.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _costDd<int?>('', _repairShopId, items, (v) => setState(() => _repairShopId = v));
  }

  Widget _costPlateDropdown(List<VehicleArchive> archives) {
    final plates = archives.map((a) => a.plateNumber).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final items = [const DropdownMenuItem<String?>(value: null, child: Text('全部车辆', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...plates.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _costDd<String?>('', _plateNumber, items, (v) => setState(() => _plateNumber = v));
  }

  Widget _costVehicleTypeDropdown(List<VehicleArchive> archives) {
    final typeSet = <String>{};
    for (final a in archives) {
      if (a.vehicleType != null && a.vehicleType!.isNotEmpty) {
        typeSet.add(a.vehicleType!);
      }
    }
    final types = typeSet.toList()..sort();
    final items = [const DropdownMenuItem<String?>(value: null, child: Text('全部车型', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...types.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _costDd<String?>('', _vehicleType, items, (v) => setState(() => _vehicleType = v));
  }

  Widget _costDeptDropdown(List<Department> depts) {
    final items = [const DropdownMenuItem<int?>(value: null, child: Text('全部归属部门', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...depts.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _costDd<int?>('', _departmentId, items, (v) => setState(() => _departmentId = v));
  }

  Widget _costDriverDropdown(List<AdminUser> drivers) {
    final items = [const DropdownMenuItem<String?>(value: null, child: Text('全部驾驶员', style: TextStyle(color: AppColors.text2, fontSize: 12))), ...drivers.map((d) => DropdownMenuItem<String?>(value: d.name, child: Text(d.name, style: const TextStyle(color: AppColors.text, fontSize: 12))))];
    return _costDd<String?>('', _driverKeyword.isNotEmpty ? _driverKeyword : null, items, (v) => setState(() => _driverKeyword = v ?? ''));
  }

  Widget _costDd<T>(String label, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChange) {
    return Container(
      height: 36, padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(value: value, items: items, onChanged: onChange, dropdownColor: AppColors.surface2, icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 20), isDense: true),
      ),
    );
  }

  Widget _sumRow(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 2), child: Row(children: [Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.text2)), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))]));
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold)));

  Widget _subCard(String name, String detail, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Row(children: [Expanded(child: Text(name, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))), Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.text2))]),
    );
  }

  Widget _itemRow(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: item.source == '内部' ? AppColors.success.withValues(alpha: 0.1) : AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)), child: Text(item.source, style: TextStyle(fontSize: 9, color: item.source == '内部' ? AppColors.success : AppColors.info))),
            const SizedBox(width: 6),
            Expanded(child: Text(item.vehicleName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            if (item.driverName != null) ...[Text(item.driverName!, style: const TextStyle(fontSize: 10, color: AppColors.text2)), const Text(' · ', style: TextStyle(fontSize: 10, color: AppColors.text2))],
            if (item.repairShopName != null) Text(item.repairShopName!, style: const TextStyle(fontSize: 10, color: AppColors.text2)),
          ]),
        ])),
        Text('¥${item.quoteAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger)),
      ]),
    );
  }

  Widget _loading() => Container(height: 36, alignment: Alignment.center, child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)));
  Widget _error() => Container(height: 36, alignment: Alignment.center, child: const Text('加载失败', style: TextStyle(color: AppColors.text2, fontSize: 11)));

  Future<void> _export() async {
    try {
      final path = await DownloadService.instance.downloadXlsx('/admin/export-cost-xlsx', {
        if (_dateFromStr != null) 'date_from': _dateFromStr,
        if (_dateToStr != null) 'date_to': _dateToStr,
        if (_deptType != null) 'dept_type': _deptType,
        if (_departmentId != null) 'department_id': _departmentId,
        if (_plateNumber != null) 'plate_keyword': _plateNumber,
        if (_vehicleType != null) 'vehicle_type': _vehicleType,
        if (_driverKeyword.isNotEmpty) 'driver_keyword': _driverKeyword,
      }, '维修费用报表_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx');
      if (mounted) _snack(path != null ? '已保存到 Downloads，可在分享面板发送或保存' : '导出成功');
    } catch (e) { if (mounted) _snack('导出失败: $e'); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 3)));
}
