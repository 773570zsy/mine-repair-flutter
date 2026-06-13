import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/machinery.dart';
import '../../providers/machinery_provider.dart';

import '../../config/color_constants.dart';

class DispatchedPage extends ConsumerStatefulWidget {
  const DispatchedPage({super.key});

  @override
  ConsumerState<DispatchedPage> createState() => _DispatchedPageState();
}

class _DispatchedPageState extends ConsumerState<DispatchedPage> {
  String _period = 'month';
  Map<String, String?> _filters = const {'period': 'month'};

  void _setPeriod(String p) {
    _period = p;
    _filters = {'period': p};
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dispatchedListProvider(_filters));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('已派车列表'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: Column(children: [
        // 时间筛选
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: AppColors.surface,
          child: Row(children: [
            _periodBtn('今日', 'today'),
            const SizedBox(width: 6),
            _periodBtn('本月', 'month'),
            const SizedBox(width: 6),
            _periodBtn('本年', 'year'),
          ]),
        ),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (data) {
            final list = (data['list'] as List<dynamic>? ?? [])
                .map((v) => MachineryApplication.fromJson(v as Map<String, dynamic>))
                .toList();
            final stats = DispatchedStats.fromJson(data['stats'] as Map<String, dynamic>? ?? {});

            return Column(children: [
              // 统计条
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  _statText('共 ${stats.totalCount} 单'),
                  const SizedBox(width: 16),
                  _statText('营收 ¥${stats.totalRevenue.toStringAsFixed(2)}'),
                  const SizedBox(width: 16),
                  _statText('工时 ${stats.totalHours.toStringAsFixed(2)}h'),
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('暂无已派车记录', style: TextStyle(color: AppColors.text2)))
                    : RefreshIndicator(
                        color: AppColors.gold,
                        onRefresh: () async => ref.invalidate(dispatchedListProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: list.length,
                          itemBuilder: (ctx, i) => _buildRow(context, list[i]),
                        ),
                      ),
              ),
            ]);
          },
        )),
      ]),
    );
  }

  Widget _periodBtn(String label, String value) {
    final active = _period == value;
    return GestureDetector(
      onTap: () => setState(() => _setPeriod(value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surface2,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: active ? AppColors.bg : AppColors.text2, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _statText(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2));
  }

  Widget _buildRow(BuildContext context, MachineryApplication app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => context.push('/machinery/detail/${app.id}'),
        child: Row(children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.applicationNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text('${app.applicantDept} · ${app.applicantName}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.vehicleDisplay, style: const TextStyle(fontSize: 12, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(app.driverName ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('¥${(app.totalCost ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger)),
            const SizedBox(height: 2),
            Text('${(app.workingHours ?? 0).toStringAsFixed(2)}h', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ]),
        ]),
      ),
    );
  }
}
