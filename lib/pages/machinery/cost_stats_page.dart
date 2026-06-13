import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/machinery_provider.dart';

import '../../config/color_constants.dart';

class CostStatsPage extends ConsumerWidget {
  const CostStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(machineryCostStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('费用统计'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 本月统计
            _section('本月统计'),
            const SizedBox(height: 8),
            _statsGrid([
              _statTile('总申请', '${stats.thisMonth.totalCount}', Icons.assignment, AppColors.info),
              _statTile('已派车', '${stats.thisMonth.activeCount}', Icons.directions_car, AppColors.warning),
              _statTile('已完成', '${stats.thisMonth.completedCount}', Icons.check_circle, AppColors.success),
              _statTile('总费用', '¥${stats.thisMonth.totalCost.toStringAsFixed(2)}', Icons.monetization_on, AppColors.danger),
              _statTile('总工时', '${stats.thisMonth.totalHours.toStringAsFixed(2)}h', Icons.access_time, AppColors.gold),
            ]),
            const SizedBox(height: 16),

            // 汇总
            _section('历史汇总'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Expanded(child: _bigStat('累计申请', '${stats.allTime.totalCount}')),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(child: _bigStat('累计费用', '¥${stats.allTime.totalCost.toStringAsFixed(2)}', valueColor: AppColors.danger)),
              ]),
            ),

            // 最近明细
            if (stats.recentItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section('最近费用明细'),
              const SizedBox(height: 8),
              ...stats.recentItems.map(_buildRecentItem),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold));
  }

  Widget _statsGrid(List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Wrap(spacing: 8, runSpacing: 8, children: items),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 100,
      child: Column(children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
      ]),
    );
  }

  Widget _bigStat(String label, String value, {Color? valueColor}) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.text)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
    ]);
  }

  Widget _buildRecentItem(dynamic item) {
    // ignore: unused_local_variable
    final statusLabel = item.status == 'completed' || item.status == 'early_completed' ? '已完成' : item.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.applicationNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text('${item.scheduledStart} ~ ${item.scheduledEnd}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('¥${(item.totalCost ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger)),
            const SizedBox(height: 2),
            Text('${(item.workingHours ?? 0).toStringAsFixed(2)}h', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ]),
        ),
      ]),
    );
  }

}
