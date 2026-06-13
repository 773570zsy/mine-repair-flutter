import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/external_repair_order.dart';
import '../../providers/external_repair_provider.dart';

class ExternalShopOrdersPage extends ConsumerStatefulWidget {
  const ExternalShopOrdersPage({super.key});

  @override
  ConsumerState<ExternalShopOrdersPage> createState() => _ExternalShopOrdersPageState();
}

class _ExternalShopOrdersPageState extends ConsumerState<ExternalShopOrdersPage> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(externalShopOrdersProvider(_statusFilter));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('我的外修工单'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: Column(children: [
        _statusBar(),
        const Divider(color: AppColors.border, height: 1),
        Expanded(child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (orders) {
            if (orders.isEmpty) {
              return const Center(child: Text('暂无外修工单', style: TextStyle(color: AppColors.text2)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: orders.length,
              itemBuilder: (_, i) => _orderCard(orders[i]),
            );
          },
        )),
      ]),
    );
  }

  Widget _statusBar() {
    final tabs = <StatusItem>[
      StatusItem(null, '全部'),
      StatusItem('active', '进行中'),
      StatusItem('pending_approval', '待审批'),
      StatusItem('approved', '已通过'),
      StatusItem('repairing', '维修中'),
      StatusItem('completed', '待验收'),
      StatusItem('accepted', '已完成'),
      StatusItem('rejected', '已驳回'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: tabs.map((t) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => setState(() => _statusFilter = t.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusFilter == t.value ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _statusFilter == t.value ? AppColors.gold : AppColors.border),
              ),
              child: Text(t.label, style: TextStyle(fontSize: 11, color: _statusFilter == t.value ? AppColors.gold : AppColors.text2)),
            ),
          ),
        )).toList()),
      ),
    );
  }

  Widget _orderCard(ExternalRepairOrder o) {
    final stLabel = externalStatusMap[o.status] ?? o.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => context.push('/external-repair/detail/${o.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(o.orderNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
              if (o.isUrgent) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3)), child: const Text('急', style: TextStyle(fontSize: 9, color: Colors.white))),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _stColor(o.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3), border: Border.all(color: _stColor(o.status).withValues(alpha: 0.3))), child: Text(stLabel, style: TextStyle(fontSize: 10, color: _stColor(o.status), fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 6),
            Text(o.vehicleName, style: const TextStyle(fontSize: 14, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(o.faultDescription, style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Text('${o.deptName ?? ""} ${o.userName ?? ""}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
              const Spacer(),
              if (o.quoteAmount != null && o.quoteAmount! > 0)
                Text('¥${o.quoteAmount!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gold)),
            ]),
          ]),
        ),
      ),
    );
  }

  Color _stColor(String s) {
    switch (s) {
      case 'pending_accept': case 'pending_approval': case 'completed': return AppColors.warning;
      case 'approved': case 'repairing': return AppColors.info;
      case 'accepted': return AppColors.success;
      case 'rejected': return AppColors.danger;
      default: return AppColors.text2;
    }
  }
}

class StatusItem {
  final String? value;
  final String label;
  StatusItem(this.value, this.label);
}
