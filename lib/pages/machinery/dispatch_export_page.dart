import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/color_constants.dart';
import '../../providers/machinery_provider.dart';
import '../../providers/repair_provider.dart';
import '../../models/machinery.dart';
import '../../services/download_service.dart';

/// 调度员 — 历史用车导出
class DispatchExportPage extends ConsumerStatefulWidget {
  const DispatchExportPage({super.key});

  @override
  ConsumerState<DispatchExportPage> createState() => _DispatchExportPageState();
}

class _DispatchExportPageState extends ConsumerState<DispatchExportPage> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _typeFilter = '';
  final _plateCtrl = TextEditingController();
  List<MachineryApplication>? _exportData;
  bool _loading = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('zh'),
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (_, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold)), child: child!),
    );
    if (picked != null) setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
  }

  String _fmt(DateTime? d) => d != null ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' : '';

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(machineryServiceProvider).getDispatchedList(
        dateFrom: _dateFrom != null ? _fmt(_dateFrom) : null,
        dateTo: _dateTo != null ? _fmt(_dateTo) : null,
      );
      final items = (list['list'] as List<dynamic>?)
          ?.map((j) => MachineryApplication.fromJson(j as Map<String, dynamic>))
          .where((a) => a.assignedPlate != null)
          .toList() ?? [];

      var filtered = items;
      if (_plateCtrl.text.trim().isNotEmpty) {
        final kw = _plateCtrl.text.trim();
        filtered = items.where((a) => (a.assignedPlate ?? '').contains(kw)).toList();
      }
      if (_typeFilter.isNotEmpty) {
        filtered = filtered.where((a) => a.vehicleType == _typeFilter).toList();
      }
      setState(() => _exportData = filtered);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _downloadXlsx() async {
    try {
      _snack('正在生成Excel文件...');
      final path = await DownloadService.instance.downloadXlsx(
        '/machinery/export-xlsx',
        {
          if (_dateFrom != null) 'date_from': _fmt(_dateFrom),
          if (_dateTo != null) 'date_to': _fmt(_dateTo),
          if (_typeFilter.isNotEmpty) 'vehicle_type': _typeFilter,
          if (_plateCtrl.text.trim().isNotEmpty) 'plate_number': _plateCtrl.text.trim(),
        },
        '调度派车明细_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx',
      );
      _snack(path != null ? '已保存: $path' : '导出成功');
    } catch (e) {
      _snack('导出失败: $e');
    }
  }

  String _duration(MachineryApplication a) {
    if (a.workingHours != null) return a.workingHours!.toStringAsFixed(1);
    // fallback: calculate from times
    try {
      final start = DateTime.tryParse(a.scheduledStart);
      final end = DateTime.tryParse(a.scheduledEnd);
      if (start != null && end != null) {
        final h = end.difference(start).inMinutes / 60.0;
        return h.toStringAsFixed(1);
      }
    } catch (_) {}
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider).valueOrNull ?? [];
    final types = vehicles.map((v) => v.vehicleType).where((t) => t != null && t.isNotEmpty).toSet().cast<String>().toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('历史用车导出'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 筛选
          _section('筛选条件'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _dateBtn('开始日期', _dateFrom, () => _pickDate(true))),
            const SizedBox(width: 8),
            Expanded(child: _dateBtn('结束日期', _dateTo, () => _pickDate(false))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('内部编号', _plateCtrl, hint: '车牌号筛选', icon: Icons.directions_car_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _typeDropdown(types)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _export,
              icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg)) : const Icon(Icons.search_outlined, size: 18),
              label: const Text('查询', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
          const SizedBox(height: 16),

          // 结果
          if (_exportData != null) ...[
            Row(children: [
              Expanded(child: _section('导出结果（${_exportData!.length} 条）')),
              ElevatedButton.icon(
                onPressed: _downloadXlsx,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('导出XLS', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              ),
            ]),
            const SizedBox(height: 8),
            _buildTable(_exportData!),
          ],
        ]),
      ),
    );
  }

  Widget _section(String t) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
  ]);

  Widget _field(String label, TextEditingController ctrl, {String? hint, IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.text2, size: 16) : null,
        filled: true, fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }

  Widget _typeDropdown(List<String> types) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _typeFilter.isEmpty ? null : _typeFilter,
          isExpanded: true,
          hint: const Text('车辆类型', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2),
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          dropdownColor: AppColors.surface,
          items: [const DropdownMenuItem(value: '', child: Text('全部类型')), ...types.map((t) => DropdownMenuItem(value: t, child: Text(t)))],
          onChanged: (v) => setState(() => _typeFilter = v ?? ''),
        ),
      ),
    );
  }

  Widget _dateBtn(String label, DateTime? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: value != null ? AppColors.gold : AppColors.border)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, color: value != null ? AppColors.gold : AppColors.text2, size: 16),
          const SizedBox(width: 6),
          Text(value != null ? _fmt(value) : label, style: TextStyle(fontSize: 13, color: value != null ? AppColors.text : AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _buildTable(List<MachineryApplication> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.surface2),
        dataRowColor: WidgetStateProperty.all(AppColors.surface),
        border: TableBorder.all(color: AppColors.border, width: 0.5),
        columns: const [
          DataColumn(label: Text('申请日期', style: _thStyle)),
          DataColumn(label: Text('申请部门', style: _thStyle)),
          DataColumn(label: Text('费供', style: _thStyle)),
          DataColumn(label: Text('申请人', style: _thStyle)),
          DataColumn(label: Text('类型', style: _thStyle)),
          DataColumn(label: Text('内部编号', style: _thStyle)),
          DataColumn(label: Text('驾驶员', style: _thStyle)),
          DataColumn(label: Text('作业地点', style: _thStyle)),
          DataColumn(label: Text('作业时间', style: _thStyle)),
          DataColumn(label: Text('作业时长', style: _thStyle)),
          DataColumn(label: Text('费用', style: _thStyle)),
          DataColumn(label: Text('状态', style: _thStyle)),
        ],
        rows: list.map((a) => DataRow(cells: [
          _cell(a.scheduledStart.length >= 10 ? a.scheduledStart.substring(0, 10) : a.scheduledStart),
          _cell(a.applicantDept),
          _cell(a.feeProviderLabel),
          _cell(a.applicantName),
          _cell(a.vehicleType),
          _cell(a.assignedPlate ?? '-'),
          _cell(a.driverName ?? '-'),
          _cell(a.workLocation),
          _cell('${a.scheduledStart} ~ ${a.scheduledEnd}'),
          _cell('${_duration(a)}h'),
          _cell(a.totalCost != null ? '¥${a.totalCost!.toStringAsFixed(2)}' : '-', color: AppColors.danger),
          _cell(a.statusLabel),
        ])).toList(),
      ),
    );
  }

  static const _thStyle = TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600);

  DataCell _cell(String text, {Color? color}) {
    return DataCell(Text(text, style: TextStyle(fontSize: 12, color: color ?? AppColors.text)));
  }
}
