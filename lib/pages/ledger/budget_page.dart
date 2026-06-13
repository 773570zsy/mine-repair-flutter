import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/budget.dart';
import '../../providers/ledger_provider.dart';
import '../../config/color_constants.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  String _selYearMonth = '';
  bool _calculated = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('维修预算管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 20, color: AppColors.gold),
            tooltip: '增幅配置',
            onPressed: () => context.push('/ledger/budget/config'),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, size: 20, color: AppColors.gold),
            tooltip: '导入基准数据',
            onPressed: () => context.push('/ledger/budget/import'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 月份选择 + 计算
          _monthBar(),
          const SizedBox(height: 14),
          // 预算数据
          if (_calculated) _buildBudgetContent(),
          if (!_calculated)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(children: [
                Icon(Icons.account_balance_wallet, size: 48, color: AppColors.text2),
                SizedBox(height: 12),
                Text('选择月份后点击"计算预算"', style: TextStyle(color: AppColors.text2, fontSize: 14)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _monthBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.calendar_month, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        const Text('预算月份', style: TextStyle(fontSize: 13, color: AppColors.text2)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context, initialDate: DateTime.now(),
              firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)),
              helpText: '选择预算月份',
            );
            if (picked != null) {
              setState(() {
                _selYearMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
                _calculated = false;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF2a2e38), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Text(_selYearMonth, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _doCalculate(),
          icon: const Icon(Icons.calculate, size: 16),
          label: const Text('计算预算', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ]),
    );
  }

  Future<void> _doCalculate() async {
    try {
      await ref.read(ledgerActionsProvider).calculateBudget(_selYearMonth);
      if (mounted) setState(() => _calculated = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
        // 即使计算失败也尝试展示已有数据
        setState(() => _calculated = true);
      }
    }
  }

  Widget _buildBudgetContent() {
    final async = ref.watch(monthlyBudgetProvider(_selYearMonth));
    return async.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.gold))),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger)))),
      data: (summary) => Column(children: [
        _summaryCards(summary),
        const SizedBox(height: 16),
        _sectionTitle('车辆明细'),
        const SizedBox(height: 8),
        if (summary.items.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('暂无预算数据，请先导入基准数据', style: TextStyle(color: AppColors.text2))))
        else
          ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.items.length,
            itemBuilder: (ctx, i) => _vehicleRow(summary.items[i]),
          ),
      ]),
    );
  }

  Widget _summaryCards(MonthlyBudgetSummary s) {
    return Column(children: [
      Row(children: [
        _statCard('月总预算', '¥${s.totalBudget.toStringAsFixed(0)}', AppColors.gold),
        const SizedBox(width: 10),
        _statCard('月总实际', '¥${s.totalActual.toStringAsFixed(0)}', AppColors.text),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statCard('差异', s.varianceDisplay, s.isOverBudget ? AppColors.danger : AppColors.success),
        const SizedBox(width: 10),
        _statCard('统计车辆', '${s.items.length} 辆', AppColors.text2),
      ]),
    ]);
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _vehicleRow(MonthlyBudget b) {
    final barWidth = b.budgetAmount > 0
        ? ((b.actualAmount / b.budgetAmount) * 200).clamp(0.0, 300.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.vehicleDisplay, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
          _badge(b.isOver ? '超预算' : (b.isUnder ? '节余' : '持平'), b.isOver ? AppColors.danger : (b.isUnder ? AppColors.success : AppColors.text2)),
        ]),
        const SizedBox(height: 8),
        // 预算 vs 实际进度条
        Row(children: [
          const Text('预算', style: TextStyle(fontSize: 11, color: AppColors.text2)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 8,
                color: AppColors.border,
                child: Row(children: [
                  Container(width: barWidth, color: b.isOver ? AppColors.danger : AppColors.success),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('实际', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('预算: ¥${b.budgetAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.gold)),
          const Spacer(),
          Text('实际: ¥${b.actualAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: b.isOver ? AppColors.danger : AppColors.text)),
          const SizedBox(width: 12),
          Text(b.varianceDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: b.isOver ? AppColors.danger : AppColors.success)),
        ]),
        // 计算明细
        if (b.baseMonthly != null) ...[
          const SizedBox(height: 4),
          Text('基准月费 ¥${b.baseMonthly!.toStringAsFixed(0)} | 车龄 ${b.vehicleAge ?? 0}年 | 增幅 ${((b.annualIncreaseRate ?? 0) * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 10, color: AppColors.text2)),
        ],
      ]),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold));
  }
}
