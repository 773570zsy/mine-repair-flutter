import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/repair_order.dart';
import '../../providers/repair_provider.dart';
import 'order_list_common.dart';

class AllOrdersPage extends ConsumerStatefulWidget {
  const AllOrdersPage({super.key});

  @override
  ConsumerState<AllOrdersPage> createState() => _AllOrdersPageState();
}

class _AllOrdersPageState extends ConsumerState<AllOrdersPage> {
  String? _statusFilter;
  String? _searchKeyword;
  final _searchController = TextEditingController();
  int _page = 1;
  final List<RepairOrder> _orders = [];
  bool _hasMore = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() { _page = 1; _orders.clear(); _hasMore = true; });
      // 强制清除缓存，重新拉取最新数据
      ref.invalidate(allOrdersProvider(AllOrdersParams(
        status: _statusFilter,
        keyword: _searchKeyword,
        page: 1,
      )));
    }
    if (!_hasMore && !refresh) return;

    try {
      final result = await ref.read(allOrdersProvider(AllOrdersParams(
        status: _statusFilter,
        keyword: _searchKeyword,
        page: _page,
      )).future);

      if (mounted) {
        setState(() {
          if (refresh) _orders.clear();
          _orders.addAll(result.list);
          _page = result.page + 1;
          _hasMore = result.hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1d23),
      appBar: AppBar(
        title: const Text('全部工单'),
        backgroundColor: const Color(0xFF242830),
        foregroundColor: const Color(0xFFd0d4dc),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF242830),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) { setState(() => _searchKeyword = _searchController.text.trim().isEmpty ? null : _searchController.text.trim()); _loadData(refresh: true); },
              style: const TextStyle(color: Color(0xFFd0d4dc), fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索工单号/车牌/驾驶员...',
                hintStyle: const TextStyle(color: Color(0xFF9098a6), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFc8a04a), size: 20),
                filled: true,
                fillColor: const Color(0xFF1a1d23),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          _buildStatusFilter(),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFc8a04a),
              onRefresh: () => _loadData(refresh: true),
              child: _orders.isEmpty
                  ? const Center(child: Text('暂无工单', style: TextStyle(color: Color(0xFF9098a6), fontSize: 13)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          OrderTable(orders: _orders, role: 'admin'),
                          if (_hasMore)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: const CircularProgressIndicator(color: Color(0xFFc8a04a), strokeWidth: 2),
                            ),
                        ],
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
      {'label': '待接单', 'value': 'pending_accept'},
      {'label': '待审批', 'value': 'pending_quote,pending_approval'},
      {'label': '维修中', 'value': 'approved,repairing,completed'},
      {'label': '已完成', 'value': 'accepted'},
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFF1a1d23),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final selected = _statusFilter == f['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: GestureDetector(
                onTap: () { setState(() => _statusFilter = f['value']); _loadData(refresh: true); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFc8a04a) : const Color(0xFF2a2e38),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(f['label']!,
                      style: TextStyle(fontSize: 11, color: selected ? const Color(0xFF1a1d23) : const Color(0xFF9098a6), fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
