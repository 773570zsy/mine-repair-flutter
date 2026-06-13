import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/ledger_provider.dart';

import '../../config/color_constants.dart';

class LedgerHomePage extends ConsumerStatefulWidget {
  const LedgerHomePage({super.key});

  @override
  ConsumerState<LedgerHomePage> createState() => _LedgerHomePageState();
}

class _LedgerHomePageState extends ConsumerState<LedgerHomePage> {
  String _selMonth = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ledgerSummaryProvider(_selMonth));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('单车核算'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 月份选择
          _monthPicker(),
          const SizedBox(height: 14),

          // 汇总数据
          async.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.gold))),
            error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
            data: (summary) => Column(children: [
              _summaryGrid(summary),
              if (!summary.hasKpi) ...[
                const SizedBox(height: 12),
                _kpiWarning(),
              ],
            ]),
          ),

          const SizedBox(height: 24),
          _sectionTitle('功能导航'),
          const SizedBox(height: 10),
          _navCards(),
        ]),
      ),
    );
  }

  Widget _monthPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.calendar_month, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        const Text('统计月份', style: TextStyle(fontSize: 13, color: AppColors.text2)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              helpText: '选择核算月份',
            );
            if (picked != null) {
              setState(() {
                _selMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF2a2e38), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Text(_selMonth, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
          ),
        ),
      ]),
    );
  }

  Widget _summaryGrid(dynamic summary) {
    return Column(children: [
      Row(children: [
        _statCard(Icons.local_gas_station, '燃油成本', '¥${summary.fuelCost.toStringAsFixed(2)}', AppColors.warning),
        const SizedBox(width: 10),
        _statCard(Icons.build, '维修费用', '¥${summary.repairCost.toStringAsFixed(2)}', AppColors.warning),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statCard(Icons.inventory_2, '配件费用', '¥${summary.partsCost.toStringAsFixed(2)}', AppColors.warning),
        const SizedBox(width: 10),
        _statCard(Icons.account_balance, '总成本', '¥${summary.totalCost.toStringAsFixed(2)}', AppColors.danger),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statCard(Icons.trending_up, '总收入', '¥${summary.totalRevenue.toStringAsFixed(2)}', AppColors.gold),
        const SizedBox(width: 10),
        _statCard(summary.totalProfit >= 0 ? Icons.check_circle : Icons.trending_down, '盈亏', summary.profitDisplay, summary.totalProfit >= 0 ? AppColors.success : AppColors.danger),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statCard(Icons.description, '已审批清单', '${summary.approvedLedgers}', AppColors.text),
        const SizedBox(width: 10),
        _statCard(Icons.emoji_events, 'KPI状态', summary.hasKpi ? '已计算' : '未计算', summary.hasKpi ? AppColors.success : AppColors.warning),
      ]),
    ]);
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _kpiWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: AppColors.warning, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text('KPI尚未计算，请先生成月度核算清单并审批通过后，在KPI排名页面点击"重新计算"', style: TextStyle(fontSize: 12, color: AppColors.warning))),
      ]),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold));
  }

  Widget _navCards() {
    return Column(children: [
      Row(children: [
        _navCard(Icons.description, '月度清单', '生成/提交/审批', AppColors.gold, () => context.push('/ledger/monthly')),
        const SizedBox(width: 10),
        _navCard(Icons.account_balance_wallet, '维修预算', '预算 vs 实际', AppColors.gold, () => context.push('/ledger/budget')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _navCard(Icons.emoji_events, 'KPI排名', '考核评分/排名', AppColors.gold, () => context.push('/ledger/kpi')),
        const SizedBox(width: 10),
        _navCard(Icons.tune, '阈值配置', 'KPI奖惩阈值', AppColors.text2, () => context.push('/ledger/thresholds')),
      ]),
    ]);
  }

  Widget _navCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.text2), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
