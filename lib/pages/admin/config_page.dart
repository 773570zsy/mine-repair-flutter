import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';

import '../../config/color_constants.dart';

class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({super.key});

  @override
  ConsumerState<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends ConsumerState<ConfigPage> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminConfigProvider);
    final actions = ref.read(adminActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('系统配置'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          TextButton(onPressed: _saving ? null : () => _save(actions), child: Text(_saving ? '保存中...' : '保存', style: const TextStyle(color: AppColors.gold, fontSize: 13))),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (config) => SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _configSection('基础配置', [
              _configItem('油价 (元/升)', 'fuel_unit_price', config, hint: '用于计算燃油成本，默认8.5'),
              _configItem('月制度台班 (天)', 'monthly_work_days', config, hint: 'KPI利用率基准，默认26'),
            ]),
            const SizedBox(height: 16),
            _configSection('当前所有配置项', config.entries.where((e) => !['fuel_unit_price', 'monthly_work_days'].contains(e.key)).map((e) => _configItemRaw(e.key, e.value)).toList()),
            if (config.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('暂无配置项', style: TextStyle(color: AppColors.text2)))),
          ]),
        ),
      ),
    );
  }

  Widget _configSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
      const SizedBox(height: 8),
      ...children,
    ]);
  }

  Widget _configItem(String label, String key, Map<String, String> config, {String hint = ''}) {
    if (!_ctrls.containsKey(key)) {
      _ctrls[key] = TextEditingController(text: config[key] ?? '');
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))),
          if (hint.isNotEmpty) const SizedBox(width: 8),
          Expanded(child: Text(hint, style: const TextStyle(fontSize: 10, color: AppColors.text2))),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrls[key],
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: const InputDecoration(
            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
        ),
      ]),
    );
  }

  Widget _configItemRaw(String key, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Text(key, style: const TextStyle(fontSize: 11, color: AppColors.text2))),
        Text(value, style: const TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _save(dynamic actions) async {
    final config = <String, String>{};
    for (final e in _ctrls.entries) {
      config[e.key] = e.value.text;
    }
    setState(() => _saving = true);
    try {
      await actions.saveConfig(config);
      if (mounted) { _snack('配置保存成功', AppColors.success); ref.invalidate(adminConfigProvider); }
    } catch (e) { _snack('$e', AppColors.danger); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  void _snack(String m, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: bg));
  }
}
