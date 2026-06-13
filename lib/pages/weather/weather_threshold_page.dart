import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/color_constants.dart';
import '../../models/weather.dart';
import '../../providers/weather_provider.dart';

class WeatherThresholdPage extends ConsumerWidget {
  const WeatherThresholdPage({super.key});

  static const _typeLabels = {
    'rainstorm': '暴雨',
    'strong_wind': '大风',
    'snowstorm': '暴雪',
    'sandstorm': '沙尘暴',
    'thunderstorm': '雷电',
    'low_visibility': '低能见度/大雾',
  };

  static const _levelLabels = {
    'blue': '蓝色',
    'yellow': '黄色',
    'orange': '橙色',
    'red': '红色',
  };

  static const _levelColors = {
    'blue': Color(0xFF4A90D9),
    'yellow': Color(0xFFD4A017),
    'orange': Color(0xFFE07B3C),
    'red': Color(0xFFE05555),
  };

  static const _typeUnits = {
    'rainstorm': 'mm/h',
    'strong_wind': 'm/s',
    'snowstorm': 'mm/12h',
    'sandstorm': 'm',
    'thunderstorm': '次/10min',
    'low_visibility': 'm',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherThresholdsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('天气预警阈值配置'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            tooltip: '添加阈值',
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
        data: (thresholds) {
          if (thresholds.isEmpty) {
            return const Center(child: Text('暂无阈值配置', style: TextStyle(color: AppColors.text2)));
          }
          // 按天气类型分组
          final grouped = <String, List<WeatherThreshold>>{};
          for (final t in thresholds) {
            grouped.putIfAbsent(t.weatherType, () => []).add(t);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.length,
            itemBuilder: (ctx, i) {
              final type = grouped.keys.elementAt(i);
              final items = grouped[type]!;
              // 按级别排序：蓝黄橙红
              items.sort((a, b) {
                const order = {'blue': 0, 'yellow': 1, 'orange': 2, 'red': 3};
                return order[a.level]!.compareTo(order[b.level]!);
              });
              return _buildGroup(context, ref, type, items);
            },
          );
        },
      ),
    );
  }

  Widget _buildGroup(BuildContext context, WidgetRef ref, String type, List<WeatherThreshold> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: AppColors.gold, size: 16),
            const SizedBox(width: 6),
            Text(_typeLabels[type] ?? type,
                style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_typeUnits[type] ?? ''}',
                style: const TextStyle(color: AppColors.text2, fontSize: 11)),
          ]),
        ),
        ...items.map((t) => _buildRow(context, ref, t)),
      ]),
    );
  }

  Widget _buildRow(BuildContext context, WidgetRef ref, WeatherThreshold t) {
    final lc = _levelColors[t.level] ?? AppColors.text2;
    return InkWell(
      onTap: () => _showForm(context, ref, threshold: t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: lc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: lc.withValues(alpha: 0.3)),
            ),
            child: Text(
              _levelLabels[t.level] ?? t.level,
              style: TextStyle(color: lc, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '阈值: ${t.thresholdValue} ${_typeUnits[t.weatherType] ?? ''}',
            style: const TextStyle(color: AppColors.text, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            onPressed: () => _confirmDelete(context, ref, t),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, WeatherThreshold t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认删除', style: TextStyle(color: AppColors.text)),
        content: Text('删除${_typeLabels[t.weatherType]} ${_levelLabels[t.level]}阈值？',
            style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            try {
              await ref.read(weatherActionsProvider.notifier).deleteThreshold(t.id);
            } catch (_) {}
          }, child: const Text('删除', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, {WeatherThreshold? threshold}) {
    showDialog(
      context: context,
      builder: (ctx) => _ThresholdFormDialog(threshold: threshold),
    );
  }
}

class _ThresholdFormDialog extends ConsumerStatefulWidget {
  final WeatherThreshold? threshold;
  const _ThresholdFormDialog({this.threshold});

  @override
  ConsumerState<_ThresholdFormDialog> createState() => _ThresholdFormDialogState();
}

class _ThresholdFormDialogState extends ConsumerState<_ThresholdFormDialog> {
  String _weatherType = 'rainstorm';
  String _level = 'blue';
  final _valueCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.threshold != null;

  @override
  void initState() {
    super.initState();
    if (widget.threshold != null) {
      _weatherType = widget.threshold!.weatherType;
      _level = widget.threshold!.level;
      _valueCtrl.text = widget.threshold!.thresholdValue.toString();
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = double.tryParse(_valueCtrl.text);
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的正数阈值'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'weather_type': _weatherType,
        'level': _level,
        'threshold_value': v,
      };
      if (_isEdit) {
        await ref.read(weatherActionsProvider.notifier).updateThreshold(widget.threshold!.id, data);
      } else {
        await ref.read(weatherActionsProvider.notifier).saveThreshold(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_isEdit ? '编辑阈值' : '添加阈值', style: const TextStyle(color: AppColors.text, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!_isEdit) ...[
          DropdownButtonFormField<String>(
            value: _weatherType,
            items: WeatherThresholdPage._typeLabels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: AppColors.text, fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() => _weatherType = v!),
            decoration: _dec('天气类型'),
            dropdownColor: AppColors.surface2,
          ),
          const SizedBox(height: 10),
        ],
        DropdownButtonFormField<String>(
          value: _level,
          items: WeatherThresholdPage._levelLabels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(color: WeatherThresholdPage._levelColors[e.key], fontSize: 13))))
              .toList(),
          onChanged: (v) => setState(() => _level = v!),
          decoration: _dec('预警等级'),
          dropdownColor: AppColors.surface2,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _valueCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _dec('阈值 (${WeatherThresholdPage._typeUnits[_weatherType] ?? ''})'),
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
          child: Text(_saving ? '...' : '保存', style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
    border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}
