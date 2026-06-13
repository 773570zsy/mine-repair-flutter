import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/external_repair_order.dart';
import '../../providers/external_repair_provider.dart';

class ExternalPendingAcceptPage extends ConsumerStatefulWidget {
  const ExternalPendingAcceptPage({super.key});

  @override
  ConsumerState<ExternalPendingAcceptPage> createState() => _ExternalPendingAcceptPageState();
}

class _ExternalPendingAcceptPageState extends ConsumerState<ExternalPendingAcceptPage> {
  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(externalPendingAcceptProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('外修待接单'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('暂无待接单', style: TextStyle(color: AppColors.text2)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: orders.length,
            itemBuilder: (_, i) => _card(context, orders[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, ExternalRepairOrder o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.orderNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
          if (o.isUrgent) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3)), child: const Text('急', style: TextStyle(fontSize: 9, color: Colors.white))),
        ]),
        const SizedBox(height: 4),
        Text(o.vehicleName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(o.faultDescription, style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          Text(o.deptName ?? '', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
          const SizedBox(width: 8),
          Text(o.userName ?? '', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
          const Spacer(),
          Text(o.createdAt?.substring(0, 10) ?? '', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showAcceptDialog(context, o),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: const Text('接单并报价', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  void _showAcceptDialog(BuildContext context, ExternalRepairOrder o) {
    final amountCtrl = TextEditingController();
    final partsCtrl = TextEditingController();
    final laborCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    final detailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('接单并填写报价', style: TextStyle(color: AppColors.text, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _df(ctx, '报价金额 (¥)', amountCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _df(ctx, '配件费用 (¥)', partsCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _df(ctx, '工时费用 (¥)', laborCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _df(ctx, '台班费用 (¥)', hoursCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _df(ctx, '预估天数', daysCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
              controller: detailCtrl,
              maxLines: 2,
              style: const TextStyle(color: AppColors.text, fontSize: 13),
              decoration: const InputDecoration(
                labelText: '报价说明',
                labelStyle: TextStyle(color: AppColors.text2, fontSize: 12),
                filled: true, fillColor: AppColors.bg,
                contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写有效报价金额')));
                return;
              }
              Navigator.pop(ctx);
              try {
                final provider = ref.read(externalRepairActionsProvider.notifier);
                await provider.acceptAndQuote(
                  orderId: o.id,
                  quoteAmount: amount,
                  partsCost: double.tryParse(partsCtrl.text) ?? 0,
                  laborCost: double.tryParse(laborCtrl.text) ?? 0,
                  hoursCost: double.tryParse(hoursCtrl.text) ?? 0,
                  quoteDetail: detailCtrl.text,
                  estimatedDays: int.tryParse(daysCtrl.text),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('接单成功')));
                  ref.invalidate(externalPendingAcceptProvider);
                  ref.invalidate(externalShopOrdersProvider(null));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            child: const Text('确认接单'),
          ),
        ],
      ),
    );
  }

  Widget _df(BuildContext ctx, String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
        filled: true, fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
      ),
    );
  }
}
