import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ledger.dart';
import '../../providers/ledger_provider.dart';

import '../../config/color_constants.dart';

class ThresholdConfigPage extends ConsumerStatefulWidget {
  const ThresholdConfigPage({super.key});

  @override
  ConsumerState<ThresholdConfigPage> createState() => _ThresholdConfigPageState();
}

class _ThresholdConfigPageState extends ConsumerState<ThresholdConfigPage> {
  Map<String, List<KpiThreshold>> _grouped = {};
  bool _editing = false;
  bool _saving = false;

  // 编辑中的本地副本
  late List<KpiThreshold> _editList;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(thresholdsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('KPI阈值配置'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (_editing) ...[
            TextButton(
              onPressed: () => setState(() { _editing = false; _editList = []; }),
              child: const Text('取消', style: TextStyle(color: AppColors.text2, fontSize: 13)),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中...' : '保存', style: const TextStyle(color: AppColors.gold, fontSize: 13)),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.gold, size: 20),
              onPressed: () {
                setState(() {
                  _editing = true;
                  _editList = _grouped.values.expand((list) => list).map((t) => KpiThreshold(
                    vehicleType: t.vehicleType, kpiKey: t.kpiKey,
                    upperLimit: t.upperLimit, lowerLimit: t.lowerLimit,
                    penaltyAmount: t.penaltyAmount, rewardAmount: t.rewardAmount,
                  )).toList();
                });
              },
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (data) {
          // 仅在非编辑状态更新数据
          if (!_editing) _grouped = data.grouped;

          if (_grouped.isEmpty) {
            return const Center(child: Text('暂无阈值配置', style: TextStyle(color: AppColors.text2)));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(children: _grouped.entries.map((entry) => _buildVehicleTypeCard(entry.key, entry.value)).toList()),
          );
        },
      ),
    );
  }

  Widget _buildVehicleTypeCard(String vehicleType, List<KpiThreshold> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 标题
        Row(children: [
          const Icon(Icons.directions_car, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(vehicleType, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gold)),
        ]),
        const SizedBox(height: 12),

        // 表头
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(4)),
          child: const Row(children: [
            Expanded(flex: 2, child: _Th('KPI指标')),
            Expanded(flex: 3, child: _Th('说明')),
            Expanded(flex: 1, child: _Th('上限', align: TextAlign.center)),
            Expanded(flex: 1, child: _Th('下限', align: TextAlign.center)),
            Expanded(flex: 1, child: _Th('罚金', align: TextAlign.center)),
            Expanded(flex: 1, child: _Th('奖金', align: TextAlign.center)),
          ]),
        ),

        const SizedBox(height: 4),
        ...items.map((t) => _buildRow(t)),
      ]),
    );
  }

  Widget _buildRow(KpiThreshold t) {
    if (_editing) {
      final idx = _editList.indexWhere((e) => e.vehicleType == t.vehicleType && e.kpiKey == t.kpiKey);
      final item = idx >= 0 ? _editList[idx] : t;

      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3)))),
        child: Row(children: [
          Expanded(flex: 2, child: Text(t.kpiLabel, style: const TextStyle(fontSize: 11, color: AppColors.text, fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: Text(t.kpiDesc, style: const TextStyle(fontSize: 10, color: AppColors.text2))),
          Expanded(flex: 1, child: _editField(item.upperLimit.toString(), (v) => _updateEditList(idx, 'upperLimit', double.tryParse(v) ?? 0))),
          Expanded(flex: 1, child: _editField(item.lowerLimit.toString(), (v) => _updateEditList(idx, 'lowerLimit', double.tryParse(v) ?? 0))),
          Expanded(flex: 1, child: _editField(item.penaltyAmount.toString(), (v) => _updateEditList(idx, 'penaltyAmount', double.tryParse(v) ?? 0))),
          Expanded(flex: 1, child: _editField(item.rewardAmount.toString(), (v) => _updateEditList(idx, 'rewardAmount', double.tryParse(v) ?? 0))),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3)))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(t.kpiLabel, style: const TextStyle(fontSize: 11, color: AppColors.text, fontWeight: FontWeight.w500))),
        Expanded(flex: 3, child: Text(t.kpiDesc, style: const TextStyle(fontSize: 10, color: AppColors.text2))),
        Expanded(flex: 1, child: Text(t.upperLimit > 0 ? t.upperLimit.toString() : '-', style: const TextStyle(fontSize: 11, color: AppColors.text), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Text(t.lowerLimit > 0 ? t.lowerLimit.toString() : '-', style: const TextStyle(fontSize: 11, color: AppColors.text), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Text('¥${t.penaltyAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.danger), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Text('¥${t.rewardAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.success), textAlign: TextAlign.center)),
      ]),
    );
  }

  void _updateEditList(int idx, String field, double value) {
    if (idx < 0) return;
    final old = _editList[idx];
    _editList[idx] = KpiThreshold(
      vehicleType: old.vehicleType, kpiKey: old.kpiKey,
      upperLimit: field == 'upperLimit' ? value : old.upperLimit,
      lowerLimit: field == 'lowerLimit' ? value : old.lowerLimit,
      penaltyAmount: field == 'penaltyAmount' ? value : old.penaltyAmount,
      rewardAmount: field == 'rewardAmount' ? value : old.rewardAmount,
    );
  }

  Widget _editField(String value, ValueChanged<String> onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextField(
        controller: TextEditingController(text: value == '0' || value == '0.0' ? '' : _stripDec(value)),
        decoration: const InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(3)), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(3)), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(3)), borderSide: BorderSide(color: AppColors.gold)),
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          isDense: true,
        ),
        style: const TextStyle(color: AppColors.text, fontSize: 11),
        keyboardType: TextInputType.number,
        onChanged: onChange,
      ),
    );
  }

  String _stripDec(String v) {
    if (v.endsWith('.0') || v.endsWith('.00')) return v.split('.')[0];
    return v;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(ledgerActionsProvider).saveThresholds(_editList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('阈值保存成功'), backgroundColor: AppColors.success));
        setState(() { _editing = false; _saving = false; });
        ref.invalidate(thresholdsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
        setState(() => _saving = false);
      }
    }
  }
}

/// 表头Text widget
class _Th extends StatelessWidget {
  final String text;
  final TextAlign? align;
  const _Th(this.text, {this.align});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600), textAlign: align);
  }
}
