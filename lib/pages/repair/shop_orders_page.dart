import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/repair_provider.dart';
import 'order_list_common.dart';

class ShopOrdersPage extends ConsumerStatefulWidget {
  const ShopOrdersPage({super.key});

  @override
  ConsumerState<ShopOrdersPage> createState() => _ShopOrdersPageState();
}

class _ShopOrdersPageState extends ConsumerState<ShopOrdersPage> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(shopOrdersProvider(_statusFilter));

    return Scaffold(
      backgroundColor: const Color(0xFF1a1d23),
      appBar: AppBar(
        title: const Text('我的工单'),
        backgroundColor: const Color(0xFF242830),
        foregroundColor: const Color(0xFFd0d4dc),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFc8a04a),
              onRefresh: () async => ref.invalidate(shopOrdersProvider(_statusFilter)),
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFc8a04a))),
                error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: Color(0xFFe05555)))),
                data: (orders) => SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: OrderTable(orders: orders, role: 'repair_shop'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    final filters = [
      {'label': '全部', 'value': null},
      {'label': '待报价', 'value': 'pending_quote'},
      {'label': '待审批', 'value': 'pending_approval'},
      {'label': '已通过', 'value': 'approved'},
      {'label': '维修中', 'value': 'repairing'},
      {'label': '待验收', 'value': 'completed'},
      {'label': '已完成', 'value': 'accepted'},
      {'label': '已驳回', 'value': 'rejected'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFF242830),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final selected = _statusFilter == f['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _statusFilter = f['value']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFc8a04a) : const Color(0xFF2a2e38),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(f['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? const Color(0xFF1a1d23) : const Color(0xFF9098a6),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
