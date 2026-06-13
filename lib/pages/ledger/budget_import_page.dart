import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ledger_provider.dart';
import '../../config/color_constants.dart';

class BudgetImportPage extends ConsumerStatefulWidget {
  const BudgetImportPage({super.key});

  @override
  ConsumerState<BudgetImportPage> createState() => _BudgetImportPageState();
}

class _BudgetImportPageState extends ConsumerState<BudgetImportPage> {
  String _baseYear = '';
  final List<_ImportRow> _rows = [];
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _baseYear = '${DateTime.now().year - 1}';
    // 默认添加3行空行
    _rows.addAll([_ImportRow(), _ImportRow(), _ImportRow()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('导入基准数据'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _importing ? null : _doImport,
            child: Text(_importing ? '导入中...' : '导入', style: const TextStyle(color: AppColors.gold, fontSize: 14)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _baseYearField(),
          const SizedBox(height: 8),
          const Text('录入各车上一年度（维修费+配件领用费）总额，系统自动 ÷12 计算月基准', style: TextStyle(fontSize: 11, color: AppColors.text2)),
          const SizedBox(height: 14),
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              Expanded(flex: 3, child: Text('车辆编号', style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600))),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('年度总费用(元)', style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600))),
              SizedBox(width: 30),
            ]),
          ),
          const SizedBox(height: 6),
          ..._rows.asMap().entries.map((e) => _buildRow(e.key, e.value)),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _rows.add(_ImportRow())),
              icon: const Icon(Icons.add, size: 16, color: AppColors.gold),
              label: const Text('添加一行', style: TextStyle(color: AppColors.gold, fontSize: 13)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _baseYearField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.date_range, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        const Text('基准年份', style: TextStyle(fontSize: 13, color: AppColors.text2)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context, initialDate: DateTime.now().subtract(const Duration(days: 365)),
              firstDate: DateTime(2020), lastDate: DateTime.now(),
              helpText: '选择基准年份',
            );
            if (picked != null) {
              setState(() => _baseYear = '${picked.year}');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF2a2e38), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Text(_baseYear, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
          ),
        ),
      ]),
    );
  }

  Widget _buildRow(int index, _ImportRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.plateCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(border: InputBorder.none, hintText: '例: ZK-001', hintStyle: TextStyle(color: AppColors.text2, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: row.costCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(border: InputBorder.none, hintText: '例: 50000', hintStyle: TextStyle(color: AppColors.text2, fontSize: 12)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
          onPressed: () => setState(() => _rows.removeAt(index)),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        ),
      ]),
    );
  }

  Future<void> _doImport() async {
    final records = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final plate = row.plateCtrl.text.trim();
      final cost = double.tryParse(row.costCtrl.text.trim());
      if (plate.isNotEmpty && cost != null && cost > 0) {
        records.add({'plate_number': plate, 'total_annual_cost': cost});
      }
    }
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少填写一条有效数据'), backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _importing = true);
    try {
      final msg = await ref.read(ledgerActionsProvider).importBaselines(_baseYear, records);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

class _ImportRow {
  final TextEditingController plateCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();
}
