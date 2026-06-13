import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';

import '../../config/color_constants.dart';

class AllRecordsPage extends ConsumerStatefulWidget {
  const AllRecordsPage({super.key});

  @override
  ConsumerState<AllRecordsPage> createState() => _AllRecordsPageState();
}

class _AllRecordsPageState extends ConsumerState<AllRecordsPage> {
  String? _date;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(allRecordsProvider(AllRecordsParams(date: _date, page: _page)));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('全部点检记录'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 20, color: AppColors.text2),
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('暂无记录', style: TextStyle(color: AppColors.text2)));
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async { ref.invalidate(allRecordsProvider(AllRecordsParams(date: _date, page: _page))); },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              itemBuilder: (ctx, i) => _buildCard(records[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(InspectionRecord r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(r.plateNumber ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(width: 8),
          Text(r.vehicleType ?? '', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          const Spacer(),
          Text(r.driverName ?? '', style: const TextStyle(fontSize: 12, color: AppColors.gold)),
          const SizedBox(width: 12),
          Text(r.inspectionDate, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        ]),
        const SizedBox(height: 10),
        // 早检项 2列网格
        _morningGrid(r),
        if (r.abnormalDesc != null && r.abnormalDesc!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.warning.withValues(alpha: 0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(child: Text(r.abnormalDesc!, style: const TextStyle(fontSize: 12, color: AppColors.warning))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _morningGrid(InspectionRecord r) {
    final items = <Map<String, String>>[
      {'label': '机油油位', 'value': _optionLabel(r.oilLevel)},
      {'label': '冷却液位', 'value': _optionLabel(r.coolantLevel)},
      {'label': '外观情况', 'value': _optionLabel(r.appearance)},
      {'label': '轮胎状况', 'value': _optionLabel(r.tireCondition)},
      {'label': '随车九样', 'value': _optionLabel(r.toolkitCheck)},
      {'label': '总体状态', 'value': _optionLabel(r.overallStatus)},
    ];
    return Wrap(spacing: 4, runSpacing: 4, children: items.map((item) {
      final isAbnormal = item['value'] == '异常' || item['value'] == '有损坏' || item['value'] == '磨损' || item['value'] == '需清洁' || item['value'] == '缺失';
      return Container(
        width: (MediaQuery.of(context).size.width - 56) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isAbnormal ? AppColors.danger.withValues(alpha: 0.06) : AppColors.bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isAbnormal ? AppColors.danger.withValues(alpha: 0.2) : AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Text('${item['label']}：', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          Text(item['value']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isAbnormal ? AppColors.danger : AppColors.text)),
        ]),
      );
    }).toList());
  }

  String _optionLabel(String? v) {
    const map = {
      'high': '高位', 'mid': '中位', 'low': '低位',
      'normal': '正常', 'damaged': '有损坏', 'dirty': '需清洁',
      'worn': '磨损', 'ok': '齐全', 'missing': '缺失', 'abnormal': '异常',
    };
    return map[v] ?? v ?? '-';
  }

  Future<void> _pickDate(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold)), child: child!),
    );
    if (picked != null) {
      final d = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() { _date = d; _page = 1; });
    }
  }
}
