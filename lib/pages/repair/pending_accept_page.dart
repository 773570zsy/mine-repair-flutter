import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/repair_provider.dart';
import 'order_list_common.dart';

class PendingAcceptPage extends ConsumerWidget {
  const PendingAcceptPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(pendingAcceptProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1a1d23),
      appBar: AppBar(
        title: const Text('待接工单'),
        backgroundColor: const Color(0xFF242830),
        foregroundColor: const Color(0xFFd0d4dc),
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: const Color(0xFFc8a04a),
        onRefresh: () async => ref.invalidate(pendingAcceptProvider),
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFc8a04a))),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('加载失败', style: TextStyle(color: Color(0xFFe05555))),
                const SizedBox(height: 8),
                TextButton(onPressed: () => ref.invalidate(pendingAcceptProvider), child: const Text('重试', style: TextStyle(color: Color(0xFFc8a04a)))),
              ],
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 48, color: Color(0xFF9098a6)),
                    SizedBox(height: 8),
                    Text('暂无待接工单', style: TextStyle(color: Color(0xFF9098a6), fontSize: 13)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: orders.length,
              itemBuilder: (context, i) => CompactOrderCard(
                order: orders[i],
                trailing: GestureDetector(
                  onTap: () async {
                    try {
                      await ref.read(repairActionsProvider.notifier).acceptRepairOrder(orders[i].id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('接单成功')));
                        ref.invalidate(pendingAcceptProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFc8a04a), Color(0xFFb87333)]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('接单', style: TextStyle(fontSize: 12, color: Color(0xFF1a1d23), fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
