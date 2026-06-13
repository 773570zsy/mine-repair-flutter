import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../providers/machinery_provider.dart';

/// 调度员仪表盘 — 参考3000 dashboard/dispatcher.js
class DispatcherDashboard extends ConsumerWidget {
  final BuildContext pageContext;
  const DispatcherDashboard({required this.pageContext, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(machineryPendingListProvider);
    final allAsync = ref.watch(machineryAllApplicationsProvider(const {}));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 统计
        _buildStats(pendingAsync, allAsync),
        const SizedBox(height: 14),

        // 信息查询
        _section('信息查询'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _navCard(Icons.dashboard_customize, '调度看板', '今日车辆/人员状态总览', () => context.push('/machinery/kanban'), borderColor: AppColors.success)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _navCard(Icons.folder_outlined, '在编车辆档案', '车辆详细档案查阅', () => context.push('/vehicle-archive/list'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _navCard(Icons.assignment_outlined, '全部申请', '查看所有用车申请', () => context.push('/machinery/all'))),
          const SizedBox(width: 10),
          Expanded(child: _navCard(Icons.download_outlined, '历史导出', '导出用车明细报表', () => context.push('/machinery/dispatch-export'), borderColor: AppColors.gold)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _navCard(Icons.cloud_outlined, '天气预警', '矿区天气与预警', () => context.push('/weather'))),
        ]),
      ]),
    );
  }

  Widget _buildStats(AsyncValue<Map<String, dynamic>> pendingAsync, AsyncValue<List<dynamic>> allAsync) {
    final pendingCount = (pendingAsync.valueOrNull?['list'] as List<dynamic>?)?.length ?? 0;
    final allList = allAsync.valueOrNull ?? [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayCount = allList.where((a) => a.createdAt != null && a.createdAt!.toString().startsWith(today)).length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _stat('$pendingCount', '待指派申请', Icons.pending_actions_outlined, pendingCount > 0 ? AppColors.danger : AppColors.success),
        _stat('$todayCount', '今日申请', Icons.today_outlined, AppColors.text),
        _stat('', '处理指派', Icons.assignment_turned_in_outlined, AppColors.gold, onTap: () => pageContext.push('/machinery/pending')),
        _stat('', '收益明细', Icons.bar_chart_outlined, AppColors.gold, onTap: () => pageContext.push('/machinery/dispatched')),
      ]),
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          if (value.isNotEmpty)
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _section(String title) {
    return Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
    ]);
  }

  Widget _actionCard(IconData icon, String title, String subtitle, VoidCallback onTap, {required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: color, width: 3))),
        child: Row(children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.text2, size: 20),
        ]),
      ),
    );
  }

  Widget _navCard(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? borderColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor ?? AppColors.border)),
        child: Column(children: [
          Icon(icon, size: 28, color: AppColors.gold),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.text2), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
