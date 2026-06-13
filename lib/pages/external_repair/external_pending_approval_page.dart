import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/external_repair_order.dart';
import '../../providers/external_repair_provider.dart';

class ExternalPendingApprovalPage extends ConsumerWidget {
  const ExternalPendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(externalPendingApprovalProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('外修待审批'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (orders) {
          if (orders.isEmpty) return const Center(child: Text('暂无待审批', style: TextStyle(color: AppColors.text2)));
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: orders.length,
            itemBuilder: (_, i) => _card(context, ref, orders[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, ExternalRepairOrder o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => context.push('/external-repair/detail/${o.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.orderNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
            if (o.isUrgent) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3)), child: const Text('急', style: TextStyle(fontSize: 9, color: Colors.white))),
          ]),
          const SizedBox(height: 4),
          Text(o.vehicleName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 2),
          Text('${o.deptName ?? ""}  ${o.userName ?? ""}', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          const SizedBox(height: 2),
          Text(o.repairShopName ?? '', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          const SizedBox(height: 8),
          // 报价摘要
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('报价：', style: TextStyle(fontSize: 12, color: AppColors.text2)),
                Text('¥${(o.quoteAmount ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gold)),
                if (o.estimatedDays != null) ...[const SizedBox(width: 12), Text('${o.estimatedDays}天', style: const TextStyle(fontSize: 12, color: AppColors.text2))],
              ]),
              if ((o.partsCost ?? 0) > 0 || (o.laborCost ?? 0) > 0 || (o.hoursCost ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Text('配件¥${(o.partsCost ?? 0).toStringAsFixed(2)}  工时¥${(o.laborCost ?? 0).toStringAsFixed(2)}  台班¥${(o.hoursCost ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () => _act(context, ref, o, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: const Text('通过', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: () => _reject(context, ref, o),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: const Text('驳回', style: TextStyle(fontSize: 13)),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, ExternalRepairOrder o, bool approved, {String? rejectReason}) async {
    try {
      await ref.read(externalRepairActionsProvider.notifier).approveQuote(orderId: o.id, approved: approved, rejectReason: rejectReason);
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approved ? '审批通过' : '已驳回'))); ref.invalidate(externalPendingApprovalProvider); }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _reject(BuildContext context, WidgetRef ref, ExternalRepairOrder o) {
    final reasonCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('驳回原因', style: TextStyle(color: AppColors.text)),
      content: TextField(controller: reasonCtrl, maxLines: 3, autofocus: true, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: '请填写驳回原因...', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () {
          final reason = reasonCtrl.text.trim();
          if (reason.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写驳回原因'))); return; }
          Navigator.pop(ctx);
          _act(context, ref, o, false, rejectReason: reason);
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white), child: const Text('确认驳回')),
      ],
    ));
  }
}
