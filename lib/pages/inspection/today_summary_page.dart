import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';

import '../../config/color_constants.dart';

class TodaySummaryPage extends ConsumerWidget {
  const TodaySummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('今日点检概况'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (summary) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 统计卡片
              Row(children: [
                _statCard('总车辆', '${summary.totalVehicles}', Icons.directions_car, AppColors.text),
                const SizedBox(width: 10),
                _statCard('已点检', '${summary.inspectedCount}', Icons.check_circle, AppColors.success),
                const SizedBox(width: 10),
                _statCard('未点检', '${summary.uninspectedCount}', Icons.warning_amber, summary.uninspectedCount > 0 ? AppColors.warning : AppColors.success),
              ]),
              const SizedBox(height: 16),
              // 未点检车辆列表
              if (summary.uninspected.isNotEmpty) ...[
                const Text('未点检车辆', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 8),
                ...summary.uninspected.map(_buildUninspectedRow),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: const Column(children: [
                    Icon(Icons.celebration, size: 40, color: AppColors.success),
                    SizedBox(height: 8),
                    Text('全部车辆已完成点检！', style: TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _buildUninspectedRow(UninspectedVehicle v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.directions_car, size: 16, color: AppColors.warning),
        const SizedBox(width: 8),
        Text(v.plateNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        if (v.vehicleType != null) ...[const SizedBox(width: 8), Text(v.vehicleType!, style: const TextStyle(fontSize: 12, color: AppColors.text2))],
        const Spacer(),
        if (v.driverName != null) Text(v.driverName!, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
      ]),
    );
  }
}
