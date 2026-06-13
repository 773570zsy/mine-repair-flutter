import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/budget.dart';
import '../../providers/ledger_provider.dart';
import '../../config/color_constants.dart';

class BudgetConfigPage extends ConsumerStatefulWidget {
  const BudgetConfigPage({super.key});

  @override
  ConsumerState<BudgetConfigPage> createState() => _BudgetConfigPageState();
}

class _BudgetConfigPageState extends ConsumerState<BudgetConfigPage> {
  final Map<String, double> _edits = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(budgetConfigsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('车型增幅配置'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(),
            child: Text(_saving ? '保存中...' : '保存', style: const TextStyle(color: AppColors.gold, fontSize: 14)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
        data: (configs) => ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: configs.length,
          itemBuilder: (ctx, i) => _configRow(configs[i]),
        ),
      ),
    );
  }

  Widget _configRow(config) {
    final vt = config.vehicleType as String;
    if (!_edits.containsKey(vt)) {
      _edits[vt] = config.annualIncreaseRate;
    }
    final rate = _edits[vt] ?? 0.05;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(vt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => setState(() { _edits[vt] = (rate - 0.005).clamp(0.0, 1.0); }),
                child: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.text2),
              ),
              const SizedBox(width: 8),
              Text('${(rate * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() { _edits[vt] = (rate + 0.005).clamp(0.0, 1.0); }),
                child: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.gold),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final configs = _edits.entries.map((e) => BudgetVehicleConfig(vehicleType: e.key, annualIncreaseRate: e.value)).toList();
      await ref.read(ledgerActionsProvider).saveBudgetConfigs(configs);
      ref.invalidate(budgetConfigsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已保存'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
