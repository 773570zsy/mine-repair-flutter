import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/machinery.dart';
import '../../providers/machinery_provider.dart';

/// 申请人仪表盘
class ApplicantDashboard extends ConsumerWidget {
  final BuildContext pageContext;
  const ApplicantDashboard({required this.pageContext, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(machineryCostStatsProvider);
    final activeAsync = ref.watch(activeMachineryApplicationsProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(machineryCostStatsProvider);
        ref.invalidate(activeMachineryApplicationsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildStats(statsAsync, activeAsync),
        const SizedBox(height: 12),
        _ActiveList(activeAsync: activeAsync, pageContext: pageContext),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _navCard(Icons.receipt_long_outlined, '申请记录', '查看·提前结束', () => context.push('/machinery/my-applications'))),
          const SizedBox(width: 10),
          Expanded(child: _navCard(Icons.bar_chart_outlined, '费用统计', '查看费用明细', () => context.push('/machinery/cost-stats'),
            sub: statsAsync.when(data: (d) => '累计 ¥${(d.allTime?.totalCost ?? 0).toStringAsFixed(0)}', loading: () => '加载中...', error: (_, _) => '—'))),
        ]),
      ]),
    ));
  }

  Widget _buildStats(AsyncValue<MachineryCostStats> statsAsync, AsyncValue<List<MachineryApplication>> activeAsync) {
    final activeCount = activeAsync.valueOrNull?.length ?? 0;
    final tm = statsAsync.valueOrNull?.thisMonth;
    final count = tm?.totalCount ?? 0;
    final cost = tm?.totalCost ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _statCell(Icons.add_circle_outline, '', '申请用车', AppColors.gold, onTap: () => pageContext.push('/machinery/apply')),
        _statCell(Icons.play_circle_outline, '$activeCount', '进行中', activeCount > 0 ? AppColors.success : AppColors.text2),
        _statCell(Icons.assignment_outlined, '$count', '本月申请', AppColors.text, onTap: () => pageContext.push('/machinery/my-applications')),
        _statCell(Icons.monetization_on_outlined, '¥${cost.toStringAsFixed(0)}', '本月费用', AppColors.danger),
      ]),
    );
  }

  Widget _statCell(IconData icon, String value, String label, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _navCard(IconData icon, String title, String subtitle, VoidCallback onTap, {String? sub}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Icon(icon, size: 32, color: AppColors.gold),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(sub ?? subtitle, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ]),
      ),
    );
  }
}

/// 进行中用车列表
class _ActiveList extends ConsumerWidget {
  final AsyncValue<List<MachineryApplication>> activeAsync;
  final BuildContext pageContext;

  const _ActiveList({required this.activeAsync, required this.pageContext});

  void _earlyEnd(BuildContext context, WidgetRef ref, MachineryApplication app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认提前结束', style: TextStyle(color: AppColors.text)),
        content: Text('确认结束用车 "${app.applicationNo}" 吗？', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(machineryActionsProvider).earlyEnd(app.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用车已结束')));
                ref.invalidate(activeMachineryApplicationsProvider);
                ref.invalidate(machineryCostStatsProvider);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return activeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (active) {
        if (active.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.play_circle_outline, size: 16, color: AppColors.gold),
            SizedBox(width: 6),
            Text('进行中用车', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
          ]),
          const SizedBox(height: 8),
          ...active.map((item) => _activeCard(context, ref, item, pageContext)),
        ]);
      },
    );
  }

  Widget _activeCard(BuildContext context, WidgetRef ref, MachineryApplication item, BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppColors.success, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Row(children: [
            Flexible(child: Text(item.applicationNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold))),
            const SizedBox(width: 8),
            _tag(item.statusLabel, AppColors.warning),
            if (item.isHazardous) ...[const SizedBox(width: 6), _tag('危险', AppColors.danger, icon: Icons.warning_amber_outlined)],
          ])),
          _textBtn('提前结束', AppColors.danger, () => _earlyEnd(context, ref, item)),
          const SizedBox(width: 6),
          SizedBox(width: 72, child: _textBtn('详情', AppColors.success, () => ctx.push('/machinery/detail/${item.id}'))),
        ]),
        const SizedBox(height: 8),
        _infoRow(Icons.directions_car_outlined, '车型', '${item.vehicleType} · ${item.typeLabel}用车'),
        if (item.assignedPlate != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow(Icons.local_shipping_outlined, '指派车辆', '${item.assignedPlate}（${item.assignedVehicleType} ${item.assignedVehicleModel}）'),
              if (item.driverName != null) _infoRow(Icons.person_outline, '驾驶员', item.driverName ?? ''),
              if (item.hourlyRate != null) _infoRow(Icons.sell_outlined, '小时单价', '¥${item.hourlyRate}/h'),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              Icon(Icons.hourglass_empty, size: 14, color: AppColors.warning),
              SizedBox(width: 6),
              Text('等待调度员分派车辆', style: TextStyle(fontSize: 12, color: AppColors.warning)),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        _infoRow(Icons.schedule_outlined, '时段', '${item.scheduledStart} — ${item.scheduledEnd}'),
        _infoRow(Icons.location_on_outlined, '地点', '${item.workLocation}${item.workAltitude != null ? " (${item.workAltitude})" : ""}'),
        _infoRow(Icons.assignment_outlined, '用途', item.workPurpose),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: AppColors.text2),
        const SizedBox(width: 4),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.text))),
      ]),
    );
  }

  Widget _tag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 10, color: color), const SizedBox(width: 2)],
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _textBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
