import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/machinery.dart';
import '../../providers/machinery_provider.dart';
import '../../providers/repair_provider.dart';

import '../../config/color_constants.dart';

class AllApplicationsPage extends ConsumerStatefulWidget {
  const AllApplicationsPage({super.key});

  @override
  ConsumerState<AllApplicationsPage> createState() => _AllApplicationsPageState();
}

class _AllApplicationsPageState extends ConsumerState<AllApplicationsPage> {
  String _statusFilter = 'all';
  String _vehicleFilter = '';
  final _searchCtrl = TextEditingController();
  String _searchKeyword = '';
  Map<String, String?> _filters = const {};

  void _updateFilters() {
    _filters = {
      'status': _statusFilter == 'all' ? null : _statusFilter,
      'keyword': _searchKeyword.isEmpty ? null : _searchKeyword,
    };
  }

  static const _statuses = {
    'all': '全部',
    'pending': '待指派',
    'assigned': '已指派',
    'active': '进行中',
    'completed': '已完成',
    'early_completed': '提前结束',
    'cancelled': '已取消',
  };

  static const _statusColors = {
    'pending': AppColors.warning,
    'assigned': AppColors.info,
    'active': AppColors.info,
    'completed': AppColors.success,
    'early_completed': AppColors.success,
    'cancelled': AppColors.text2,
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(machineryAllApplicationsProvider(_filters));

    // 获取车型列表用于筛选
    final vehicles = ref.watch(vehicleListProvider).valueOrNull ?? [];
    final types = vehicles.map((v) => v.vehicleType).where((t) => t.isNotEmpty).toSet().toList()..sort();

    // 本地筛选
    List<MachineryApplication>? filtered;
    final rawList = async.valueOrNull ?? [];
    if (_statusFilter == 'active') {
      filtered = rawList.where((a) => a.status == 'assigned' || a.status == 'in_progress').toList();
    } else if (_statusFilter == 'assigned') {
      filtered = rawList.where((a) => a.status == 'assigned').toList();
    } else {
      filtered = null;
    }
    final displayBase = filtered ?? rawList;
    final display = _vehicleFilter.isEmpty
        ? displayBase
        : displayBase.where((a) => a.vehicleType == _vehicleFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('全部申请'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.list_alt, size: 18, color: AppColors.gold),
              label: const Text('已派车列表', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w500)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: AppColors.gold, width: 1)),
              ),
              onPressed: () => context.push('/machinery/dispatched'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // 搜索栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: AppColors.surface,
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.text, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '搜索编号/申请人/部门/地点...',
                    hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 16),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 14, color: AppColors.text2), onPressed: () { _searchCtrl.clear(); _searchKeyword = ''; _updateFilters(); setState(() {}); })
                        : null,
                    filled: true, fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (v) { _searchKeyword = v.trim(); _updateFilters(); setState(() {}); },
                ),
              ),
            ),
          ]),
        ),
        // 状态Tab
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _statuses.entries.map((e) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () { _statusFilter = e.key; _updateFilters(); setState(() {}); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusFilter == e.key ? AppColors.gold : AppColors.surface2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(e.value, style: TextStyle(fontSize: 11, color: _statusFilter == e.key ? AppColors.bg : AppColors.text2, fontWeight: _statusFilter == e.key ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            )).toList()),
          ),
        ),
        // 车型筛选标签
        if (types.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: AppColors.surface,
            child: Row(children: [
              const Icon(Icons.filter_list, size: 14, color: AppColors.gold),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _typeChip('全部车型', _vehicleFilter.isEmpty, () => setState(() => _vehicleFilter = '')),
                    ...types.map((t) => _typeChip(t, _vehicleFilter == t, () => setState(() => _vehicleFilter = t))),
                  ]),
                ),
              ),
            ]),
          ),
        // 列表
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (_) {
            if (display.isEmpty) {
              return const Center(child: Text('暂无申请记录', style: TextStyle(color: AppColors.text2)));
            }
            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: () async => ref.invalidate(machineryAllApplicationsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: display.length,
                itemBuilder: (ctx, i) => _buildRow(context, display[i]),
              ),
            );
          },
        )),
      ]),
    );
  }

  Widget _typeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.gold : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: active ? AppColors.bg : AppColors.text2, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildRow(BuildContext context, MachineryApplication app) {
    final sc = _statusColors[app.status] ?? AppColors.text2;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => context.push('/machinery/detail/${app.id}'),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.applicationNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 2),
              Text('${app.applicantDept} · ${app.applicantName}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.vehicleType, style: const TextStyle(fontSize: 12, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(app.workLocation, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(app.scheduledStart.length >= 10 ? app.scheduledStart.substring(0, 10) : app.scheduledStart, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ),
          // 状态按钮宽度拉长一倍
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
            child: Text(app.statusLabel, style: TextStyle(fontSize: 11, color: sc, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}
