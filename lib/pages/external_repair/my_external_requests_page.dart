import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/external_repair_order.dart';
import '../../providers/external_repair_provider.dart';

class MyExternalRequestsPage extends ConsumerStatefulWidget {
  const MyExternalRequestsPage({super.key});

  @override
  ConsumerState<MyExternalRequestsPage> createState() => _MyExternalRequestsPageState();
}

class _MyExternalRequestsPageState extends ConsumerState<MyExternalRequestsPage> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(externalMyRequestsProvider(_statusFilter));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('我的外修单'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/external-repair/report'),
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.bg),
      ),
      body: Column(children: [
        // 状态筛选
        _statusBar(),
        const Divider(color: AppColors.border, height: 1),
        Expanded(child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (orders) {
            if (orders.isEmpty) {
              return const Center(child: Text('暂无外修记录', style: TextStyle(color: AppColors.text2)));
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
    final tabs = <String?>[
      null,
      'pending_accept', 'pending_approval', 'approved',
      'repairing', 'completed', 'accepted', 'rejected',
    ];
    final labels = ['全部', '待接单', '待审批', '已通过', '维修中', '待验收', '已完成', '已驳回'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(tabs.length, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => setState(() => _statusFilter = tabs[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusFilter == tabs[i] ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _statusFilter == tabs[i] ? AppColors.gold : AppColors.border),
              ),
              child: Text(labels[i], style: TextStyle(fontSize: 11, color: _statusFilter == tabs[i] ? AppColors.gold : AppColors.text2)),
            ),
          ),
        ))),
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
              if (o.isUrgent)
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3)), child: const Text('急', style: TextStyle(fontSize: 9, color: Colors.white))),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _stColor(o.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3), border: Border.all(color: _stColor(o.status).withValues(alpha: 0.3))),
                child: Text(stLabel, style: TextStyle(fontSize: 10, color: _stColor(o.status), fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 6),
            Text(o.vehicleName, style: const TextStyle(fontSize: 14, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(o.faultDescription, style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              if (o.repairShopName != null) Text(o.repairShopName!, style: const TextStyle(fontSize: 10, color: AppColors.text2)),
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
      case 'pending_accept': return AppColors.warning;
      case 'pending_approval': return AppColors.warning;
      case 'approved': return AppColors.info;
      case 'repaired': return AppColors.success;
      case 'repairing': return AppColors.info;
      case 'completed': return AppColors.warning;
      case 'accepted': return AppColors.success;
      case 'rejected': return AppColors.danger;
      default: return AppColors.text2;
    }
  }
}
