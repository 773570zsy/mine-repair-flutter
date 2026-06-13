import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../config/constants.dart';
import '../../models/repair_order.dart';
import '../../providers/repair_provider.dart';
import '../../services/repair_service.dart';

/// 修理厂仪表盘 — 对齐3000版 shop.js
class ShopDashboard extends ConsumerStatefulWidget {
  final BuildContext pageContext;
  const ShopDashboard({required this.pageContext, super.key});

  @override
  ConsumerState<ShopDashboard> createState() => _ShopDashboardState();
}

class _ShopDashboardState extends ConsumerState<ShopDashboard> {
  String _activeTab = 'all';

  static const _tabs = [
    {'l': '全部', 'v': 'all'},
    {'l': '待接单', 'v': 'pending_accept'},
    {'l': '待报价', 'v': 'pending_quote'},
    {'l': '待审批', 'v': 'pending_approval'},
    {'l': '维修中', 'v': 'repairing'},
    {'l': '已驳回', 'v': 'rejected'},
    {'l': '待验收', 'v': 'completed'},
    {'l': '已完成', 'v': 'accepted'},
  ];

  @override
  Widget build(BuildContext context) {
    final shopOrdersAsync = ref.watch(shopOrdersProvider(_activeTab == 'all' ? null : _activeTab));
    final pendingAcceptAsync = ref.watch(pendingAcceptProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildStats(shopOrdersAsync, pendingAcceptAsync),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 标题 — 3000: card-title font-size:16px
            const Row(children: [
              Icon(Icons.list_alt, size: 20, color: AppColors.gold),
              SizedBox(width: 8),
              Text('工单列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
            ]),
            const SizedBox(height: 12),
            // 标签 — 3000: tab font-size:13px padding:7px 16px
            Wrap(spacing: 8, runSpacing: 8, children: _tabs.map((t) {
              final active = t['v'] == _activeTab;
              return GestureDetector(
                onTap: () => setState(() => _activeTab = t['v']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? AppColors.gold : AppColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AppColors.gold : AppColors.border),
                  ),
                  child: Text(t['l']!, style: TextStyle(
                    fontSize: 13,
                    color: active ? AppColors.bg : AppColors.text2,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  )),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            _ShopOrderTable(
              shopAsync: shopOrdersAsync,
              pendingAsync: pendingAcceptAsync,
              activeTab: _activeTab,
              pageContext: widget.pageContext,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStats(AsyncValue<List<RepairOrder>> shopAsync, AsyncValue<List<RepairOrder>> pendingAsync) {
    final myOrders = shopAsync.valueOrNull ?? [];
    final pending = pendingAsync.valueOrNull ?? [];
    final allOrders = _mergeIfNeeded(myOrders, pending, _activeTab);

    // 3000: stat-num 30px, stat-label 12px uppercase
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        _statCell('${allOrders.length}', '全部工单', Icons.assignment, AppColors.text),
        _statCell('${pending.length}', '待接单', Icons.inbox, AppColors.danger),
        _statCell('${myOrders.where((o) => o.status == 'pending_quote').length}', '待报价', Icons.request_quote, AppColors.warning),
        _statCell('${myOrders.where((o) => o.status == 'approved' || o.status == 'repairing').length}', '维修中', Icons.build_circle, AppColors.gold),
      ]),
    );
  }

  Widget _statCell(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color, height: 1.0)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2, letterSpacing: 1.0)),
      ]),
    );
  }
}

// ==================== 工单表格 ====================

class _ShopOrderTable extends StatelessWidget {
  final AsyncValue<List<RepairOrder>> shopAsync;
  final AsyncValue<List<RepairOrder>> pendingAsync;
  final String activeTab;
  final BuildContext pageContext;

  const _ShopOrderTable({
    required this.shopAsync, required this.pendingAsync,
    required this.activeTab, required this.pageContext,
  });

  @override
  Widget build(BuildContext context) {
    if (shopAsync.isLoading && pendingAsync.isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))));
    }
    if (shopAsync.hasError && pendingAsync.hasError) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('加载失败', style: TextStyle(color: AppColors.danger, fontSize: 14))));
    }

    final myOrders = shopAsync.valueOrNull ?? [];
    final pending = pendingAsync.valueOrNull ?? [];
    final allOrders = _mergeIfNeeded(myOrders, pending, activeTab);

    if (allOrders.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('暂无工单', style: TextStyle(color: AppColors.text2, fontSize: 14))));
    }

    final display = allOrders.take(10).toList();
    return Column(children: [
      // 表头 — 3000: th font-size:11px text-transform:uppercase
      _shopHeader(),
      for (final o in display) _shopRow(o, pageContext),
      const SizedBox(height: 8),
      if (allOrders.length > 10) Center(child: TextButton(onPressed: () => pageContext.push('/repair/shop-orders'), child: const Text('查看全部工单 →', style: TextStyle(color: AppColors.gold, fontSize: 13)))),
    ]);
  }
}

// 3000: th padding:10px 12px font-size:11px uppercase
Widget _shopHeader() {
  const style = TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: const BoxDecoration(color: AppColors.surface2, border: Border(bottom: BorderSide(color: AppColors.border))),
    child: const Row(children: [
      Expanded(flex: 3, child: Text('工单号', style: style)),
      Expanded(flex: 2, child: Text('车辆', style: style)),
      Expanded(flex: 2, child: Text('报修人', style: style)),
      Expanded(flex: 3, child: Text('故障描述', style: style)),
      Expanded(flex: 2, child: Text('状态', style: style)),
      Expanded(flex: 3, child: Text('操作', style: style)),
    ]),
  );
}

// 3000: table font-size:13px
Widget _shopRow(RepairOrder o, BuildContext pageContext) {
  final statusLabel = statusMap[o.status] ?? o.status;
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(children: [
      Expanded(flex: 3, child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(o.orderNo, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w500))),
        if (o.isUrgent)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(2)),
            child: const Text('急', style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
      ])),
      Expanded(flex: 2, child: Text(o.plateNumber ?? '', style: const TextStyle(fontSize: 13, color: AppColors.text))),
      Expanded(flex: 2, child: Text(o.driverName ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.text), overflow: TextOverflow.ellipsis)),
      Expanded(flex: 3, child: Text(o.faultDescription, style: const TextStyle(fontSize: 13, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
      Expanded(flex: 2, child: _statusBadge(statusLabel, o.status)),
      Expanded(flex: 3, child: _actions(o, pageContext)),
    ]),
  );
}

// 3000: tag padding:3px 10px font-size:11px
Widget _statusBadge(String label, String status) {
  final color = switch (status) {
    'pending_accept' || 'pending_quote' || 'pending_approval' => AppColors.warning,
    'approved' || 'repairing' => AppColors.info,
    'completed' || 'accepted' => AppColors.success,
    'rejected' || 'cancelled' => AppColors.danger,
    _ => AppColors.text2,
  };
  return Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
    ),
  );
}

// 3000: btn-sm padding:5px 12px font-size:12px
Widget _actions(RepairOrder o, BuildContext pageContext) {
  return Wrap(spacing: 4, runSpacing: 4, children: [
    _btn('详情', AppColors.gold, () => pageContext.push('/repair/detail/${o.id}')),
    if (o.status == 'pending_accept') _btn('接单', AppColors.success, () => _acceptOrder(pageContext, o.id)),
    if (o.status == 'pending_quote') _btn('报价', AppColors.success, () => pageContext.push('/repair/submit-quote/${o.id}')),
    if (o.status == 'rejected') _btn('重新报价', AppColors.warning, () => pageContext.push('/repair/submit-quote/${o.id}?reQuote=1')),
    if (o.status == 'approved' || o.status == 'repairing') ...[
      _btn('进度', AppColors.gold, () => pageContext.push('/repair/update-progress/${o.id}')),
      _btn('完工', AppColors.success, () => pageContext.push('/repair/update-progress/${o.id}?complete=1')),
    ],
    if (o.status == 'completed') _btn('通知验收', AppColors.success, () => _notifyAccept(pageContext, o)),
  ]);
}

Widget _btn(String label, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
    ),
  );
}

/// 合并待接单 + 我的工单（对齐3000 shop.js：仅 all 和 pending_accept 时合并）
List<RepairOrder> _mergeIfNeeded(List<RepairOrder> myOrders, List<RepairOrder> pending, String tab) {
  if (tab == 'all' || tab == 'pending_accept') {
    final myIds = myOrders.map((o) => o.id).toSet();
    final extraPending = pending.where((o) => !myIds.contains(o.id)).toList();
    return [...extraPending, ...myOrders];
  }
  return myOrders;
}

void _acceptOrder(BuildContext ctx, int orderId) {
  showDialog(
    context: ctx,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('确认接单', style: TextStyle(color: AppColors.text, fontSize: 16)),
      content: const Text('确认接单吗？', style: TextStyle(color: AppColors.text2, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: AppColors.text2, fontSize: 14))),
        TextButton(
          onPressed: () async {
            Navigator.pop(c);
            try {
              await RepairService().acceptOrder(orderId);
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('接单成功'), backgroundColor: AppColors.success));
            } catch (e) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
            }
          },
          child: const Text('接单', style: TextStyle(color: AppColors.gold, fontSize: 14)),
        ),
      ],
    ),
  );
}

void _notifyAccept(BuildContext ctx, RepairOrder o) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('已通知 ${o.driverName ?? "驾驶员"} 验收'), backgroundColor: AppColors.success));
}
