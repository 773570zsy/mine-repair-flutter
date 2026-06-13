import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ledger_provider.dart';

import '../../config/color_constants.dart';

class KpiRankingPage extends ConsumerStatefulWidget {
  const KpiRankingPage({super.key});

  @override
  ConsumerState<KpiRankingPage> createState() => _KpiRankingPageState();
}

class _KpiRankingPageState extends ConsumerState<KpiRankingPage> {
  String _selMonth = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(kpiScoresProvider(_selMonth));
    final actions = ref.read(ledgerActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('KPI考核排名'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _recalculate(actions),
            icon: const Icon(Icons.refresh, size: 16, color: AppColors.gold),
            label: const Text('重新计算', style: TextStyle(color: AppColors.gold, fontSize: 13)),
          ),
        ],
      ),
      body: Column(children: [
        // 月份选择
        Container(
          padding: const EdgeInsets.all(10),
          color: AppColors.surface,
          child: _monthPicker(),
        ),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (list) => list.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.emoji_events, size: 48, color: AppColors.text2),
                  SizedBox(height: 8),
                  Text('暂无KPI数据', style: TextStyle(color: AppColors.text2)),
                  SizedBox(height: 4),
                  Text('请先生成月度清单并审批通过后计算', style: TextStyle(color: AppColors.text2, fontSize: 12)),
                ]))
              : RefreshIndicator(
                  color: AppColors.gold,
                  onRefresh: () async => ref.invalidate(kpiScoresProvider(_selMonth)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => _buildCard(context, list[i]),
                  ),
                ),
        )),
      ]),
    );
  }

  Widget _monthPicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: '选择月份',
        );
        if (picked != null) {
          setState(() => _selMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_month, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(_selMonth, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 18),
        ]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, dynamic kpi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kpi.rank <= 3 ? AppColors.gold.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 头部：排名 + 车辆
        Row(children: [
          Text(kpi.rankDisplay, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kpi.vehicleDisplay, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            if (kpi.model != null) Text(kpi.model!, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.gold.withValues(alpha: 0.3))),
            child: Text('${kpi.totalScore.toStringAsFixed(1)} 分', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gold)),
          ),
        ]),

        const SizedBox(height: 10),

        // KPI指标行
        _kpiRow('燃油成本', '${kpi.fuelCostPerUnit.toStringAsFixed(1)} 元/天', Icons.local_gas_station, AppColors.warning, 0.25),
        _kpiRow('维修费率', '${kpi.repairRate.toStringAsFixed(1)}%', Icons.build, AppColors.danger, 0.20),
        _kpiRow('利用率', '${kpi.utilizationRate.toStringAsFixed(1)}%', Icons.trending_up, AppColors.success, 0.20),
        _kpiRow('单位成本', '¥${kpi.unitCost.toStringAsFixed(2)}/h', Icons.attach_money, AppColors.danger, 0.15),
        _kpiRow('完好率', '${kpi.availabilityRate.toStringAsFixed(1)}%', Icons.check_circle, AppColors.success, 0.15),
        _kpiRow('安全', '${kpi.safetyScore.toStringAsFixed(0)} 分', Icons.shield, AppColors.success, 0.05),

        // 奖惩信息
        if (kpi.hasPenalty || kpi.hasReward) ...[
          const SizedBox(height: 8),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          if (kpi.hasPenalty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.danger.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.warning_amber, size: 14, color: AppColors.danger),
                const SizedBox(width: 4),
                Text('罚金: ¥${kpi.totalPenalty.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(child: Text(kpi.penalties.map((p) => p.reason).join(', '), style: const TextStyle(fontSize: 11, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          if (kpi.hasReward) ...[
            if (kpi.hasPenalty) const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.emoji_events, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text('奖金: ¥${kpi.totalReward.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(child: Text(kpi.rewards.map((r) => r.reason).join(', '), style: const TextStyle(fontSize: 11, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _kpiRow(String label, String value, IconData icon, Color color, double weight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        SizedBox(width: 55, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
        Text('${(weight * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
      ]),
    );
  }

  Future<void> _recalculate(dynamic actions) async {
    try {
      final result = await actions.calculateKpi(_selMonth);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.msg), backgroundColor: AppColors.success));
        ref.invalidate(kpiScoresProvider(_selMonth));
        ref.invalidate(ledgerSummaryProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }
}
