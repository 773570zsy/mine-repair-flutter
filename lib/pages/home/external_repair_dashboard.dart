import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/external_repair_order.dart';
import '../../providers/external_repair_provider.dart';

/// 外部车辆报修仪表盘
class ExternalRepairDashboard extends ConsumerWidget {
  final BuildContext pageContext;
  const ExternalRepairDashboard({required this.pageContext, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(externalMyRequestsProvider(null));

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
      data: (orders) {
        final activeCount = orders.where((o) =>
          o.status == 'pending_accept' || o.status == 'pending_approval' ||
          o.status == 'approved' || o.status == 'repairing').length;
        final pendingApproval = orders.where((o) => o.status == 'pending_approval').length;
        final pendingAcceptance = orders.where((o) => o.status == 'completed').length;

        return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(externalMyRequestsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 统计卡片
            Row(children: [
              Expanded(child: _statCard('$activeCount', '进行中', Icons.play_circle_outline, AppColors.info)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('$pendingApproval', '待审批', Icons.pending_actions, pendingApproval > 0 ? AppColors.warning : AppColors.text2,
                onTap: pendingApproval > 0 ? () => context.push('/external-repair/pending-approval') : null)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('$pendingAcceptance', '待验收', Icons.verified_outlined, pendingAcceptance > 0 ? AppColors.success : AppColors.text2)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('${orders.length}', '全部', Icons.assignment_outlined, AppColors.text)),
            ]),
            const SizedBox(height: 14),

            // 快捷入口
            _quickBtn(Icons.add_circle_outline, '发起报修', '提交新的外部车辆维修申请', AppColors.gold, () => context.push('/external-repair/report')),
            const SizedBox(height: 8),
            _quickBtn(Icons.receipt_long_outlined, '我的外修单', '查看全部报修记录', AppColors.info, () => context.push('/external-repair/my-requests')),
            if (pendingApproval > 0) ...[
              const SizedBox(height: 8),
              _quickBtn(Icons.pending_actions, '待审批报价 ($pendingApproval)', '修理厂已报价，请确认', AppColors.warning, () => context.push('/external-repair/pending-approval')),
            ],
            if (pendingAcceptance > 0) ...[
              const SizedBox(height: 8),
              _quickBtn(Icons.verified_outlined, '待验收 ($pendingAcceptance)', '维修完成，请验收确认', AppColors.success, () => context.push('/external-repair/my-requests?status=completed')),
            ],

            // 最近报修
            if (orders.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('最近报修', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              ...orders.take(5).map((o) => _orderRow(context, o)),
            ],
          ]),
        ));
      },
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _quickBtn(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.text2, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _orderRow(BuildContext context, ExternalRepairOrder o) {
    final stLabel = externalStatusMap[o.status] ?? o.status;
    final stColor = o.status == 'pending_approval' ? AppColors.warning :
                    o.status == 'completed' ? AppColors.success :
                    o.status == 'accepted' ? AppColors.success :
                    o.status == 'rejected' ? AppColors.danger : AppColors.text2;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => context.push('/external-repair/detail/${o.id}'),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.vehicleName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(o.orderNo, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          if (o.quoteAmount != null && o.quoteAmount! > 0)
            Padding(padding: const EdgeInsets.only(right: 8), child: Text('¥${o.quoteAmount!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: stColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)), child: Text(stLabel, style: TextStyle(fontSize: 10, color: stColor, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}
