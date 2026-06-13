import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/external_repair_order.dart';
import '../../providers/external_repair_provider.dart';

class ExternalAllOrdersPage extends ConsumerStatefulWidget {
  const ExternalAllOrdersPage({super.key});

  @override
  ConsumerState<ExternalAllOrdersPage> createState() => _ExternalAllOrdersPageState();
}

class _ExternalAllOrdersPageState extends ConsumerState<ExternalAllOrdersPage> {
  String? _status;
  String? _keyword;
  int _page = 1;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = ExternalAllOrdersParams(status: _status, keyword: _keyword, page: _page);
    final resultAsync = ref.watch(externalAllOrdersProvider(params));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('全部外修工单'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: Column(children: [
        // 搜索 + 筛选
        _filterBar(),
        const Divider(color: AppColors.border, height: 1),
        Expanded(child: resultAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (result) {
            if (result.list.isEmpty) return const Center(child: Text('暂无外修工单', style: TextStyle(color: AppColors.text2)));
            return Column(children: [
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: result.list.length,
                itemBuilder: (_, i) => _orderCard(result.list[i]),
              )),
              // 分页
              if (result.total > result.pageSize)
                _pagination(result.total, result.page, result.pageSize),
            ]);
          },
        )),
      ]),
    );
  }

  Widget _filterBar() {
    final statuses = <StatusOption>[
      StatusOption(null, '全部'), StatusOption('pending_accept', '待接单'),
      StatusOption('pending_approval', '待审批'), StatusOption('approved', '已通过'),
      StatusOption('repairing', '维修中'), StatusOption('completed', '待验收'),
      StatusOption('accepted', '已完成'), StatusOption('rejected', '已驳回'),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.surface,
      child: Column(children: [
        // 搜索
        Row(children: [
          Expanded(child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: '搜索单号/车辆名称/报修人',
              hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: AppColors.text2, size: 18),
              filled: true, fillColor: AppColors.surface2,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
            ),
            onSubmitted: (v) => setState(() { _keyword = v.isNotEmpty ? v : null; _page = 1; }),
          )),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() { _keyword = _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null; _page = 1; }),
            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.search, color: AppColors.bg, size: 18)),
          ),
        ]),
        const SizedBox(height: 6),
        // 状态筛选
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: statuses.map((s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() { _status = s.value; _page = 1; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _status == s.value ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _status == s.value ? AppColors.gold : AppColors.border),
                ),
                child: Text(s.label, style: TextStyle(fontSize: 10, color: _status == s.value ? AppColors.gold : AppColors.text2)),
              ),
            ),
          )).toList()),
        ),
      ]),
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
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(o.orderNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                if (o.isUrgent) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3)), child: const Text('急', style: TextStyle(fontSize: 9, color: Colors.white))),
              ]),
              const SizedBox(height: 4),
              Text(o.vehicleName, style: const TextStyle(fontSize: 13, color: AppColors.text)),
              const SizedBox(height: 2),
              Text('${o.deptName ?? ""}  ${o.userName ?? ""}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _stColor(o.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3), border: Border.all(color: _stColor(o.status).withValues(alpha: 0.3))), child: Text(stLabel, style: TextStyle(fontSize: 10, color: _stColor(o.status), fontWeight: FontWeight.w600))),
              const SizedBox(height: 4),
              if (o.quoteAmount != null && o.quoteAmount! > 0)
                Text('¥${o.quoteAmount!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gold)),
              if (o.repairShopName != null) ...[const SizedBox(height: 2), Text(o.repairShopName!, style: const TextStyle(fontSize: 10, color: AppColors.text2))],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _pagination(int total, int page, int pageSize) {
    final totalPages = (total / pageSize).ceil();
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.surface,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.text2, size: 20), onPressed: _page > 1 ? () => setState(() => _page--) : null),
        Text('$page / $totalPages', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.text2, size: 20), onPressed: _page < totalPages ? () => setState(() => _page++) : null),
      ]),
    );
  }

  Color _stColor(String s) {
    switch (s) {
      case 'pending_accept': case 'pending_approval': case 'completed': return AppColors.warning;
      case 'approved': case 'repairing': return AppColors.info;
      case 'accepted': return AppColors.success;
      case 'rejected': case 'cancelled': return AppColors.danger;
      default: return AppColors.text2;
    }
  }
}

class StatusOption { final String? value; final String label; StatusOption(this.value, this.label); }
