import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/repair_order.dart';
import '../../providers/repair_provider.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/silent_auto_refresh.dart';

class PendingApprovalPage extends ConsumerWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(pendingApprovalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待审批报价'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
      ),
      body: SilentAutoRefresh(
        intervalSeconds: 20,
        onRefresh: (r) => r.invalidate(pendingApprovalProvider),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingApprovalProvider);
          },
          child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('加载失败', style: TextStyle(color: Colors.red.shade400)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(pendingApprovalProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('暂无待审批报价', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, i) =>
                  _ApprovalCard(order: orders[i]),
            );
          },
        ),
      ),
    ));
  }
}

class _ApprovalCard extends ConsumerWidget {
  final RepairOrder order;

  const _ApprovalCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 车牌+工单号
            Row(
              children: [
                const Icon(Icons.directions_car, size: 20, color: Color(0xFFc8a04a)),
                const SizedBox(width: 6),
                Text(order.plateNumber ?? '未知',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (order.isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('加急',
                        style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                const Spacer(),
                Text(order.orderNo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 8),

            // 驾驶员+修理厂
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(order.driverName ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(width: 16),
                Icon(Icons.build, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.repairShopName ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 故障描述
            Text(order.faultDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 10),

            // 报价金额+预估天数
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFc8a04a).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('报价金额：',
                      style: TextStyle(fontSize: 14, color: Colors.black87)),
                  Text('¥${(order.quoteAmount ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFc8a04a))),
                  const Spacer(),
                  if (order.estimatedDays != null)
                    Text('预计 ${order.estimatedDays} 天',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),

            if (order.quoteDetail != null && order.quoteDetail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(order.quoteDetail!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
            const SizedBox(height: 12),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('驳回'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approve(context, ref, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('审批通过'),
                  ),
                ),
              ],
            ),
            // 查看详情
            TextButton.icon(
              onPressed: () => context.push('/repair/detail/${order.id}'),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('查看详情', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, bool approved) async {
    try {
      await ref.read(repairActionsProvider.notifier).approveQuote(
            orderId: order.id,
            approved: approved,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('审批通过')),
        );
        ref.invalidate(pendingApprovalProvider);
        ref.invalidate(adminDashboardProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('驳回原因'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请填写驳回原因...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('请填写驳回原因')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(repairActionsProvider.notifier).approveQuote(
                      orderId: order.id,
                      approved: false,
                      rejectReason: reason,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已驳回')),
                  );
                  ref.invalidate(pendingApprovalProvider);
                  ref.invalidate(adminDashboardProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );
  }
}
