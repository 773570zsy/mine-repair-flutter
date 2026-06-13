import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/weather.dart';
import '../../providers/weather_provider.dart';

import '../../config/color_constants.dart';

class WeatherZonePage extends ConsumerStatefulWidget {
  const WeatherZonePage({super.key});

  @override
  ConsumerState<WeatherZonePage> createState() => _WeatherZonePageState();
}

class _WeatherZonePageState extends ConsumerState<WeatherZonePage> {
  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(weatherZonesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('区域管理'),
        backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => _showZoneDialog(),
          ),
        ],
      ),
      body: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (zones) {
          if (zones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.place, size: 48, color: AppColors.text2),
                  const SizedBox(height: 10),
                  const Text('暂无区域', style: TextStyle(color: AppColors.text2)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showZoneDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增区域'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: zones.length,
            itemBuilder: (_, i) => _buildZoneRow(zones[i]),
          );
        },
      ),
    );
  }

  Widget _buildZoneRow(WeatherZone z) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.place, color: AppColors.gold, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(z.zoneName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text('${z.zoneCode} · 🧭 ${z.latitude},${z.longitude}',
                    style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.gold, size: 18),
            onPressed: () => _showZoneDialog(zone: z),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
            onPressed: () => _deleteZone(z),
          ),
        ],
      ),
    );
  }

  void _showZoneDialog({WeatherZone? zone}) {
    final isEdit = zone != null;
    final nameCtrl = TextEditingController(text: zone?.zoneName ?? '');
    final codeCtrl = TextEditingController(text: zone?.zoneCode ?? '');
    final latCtrl = TextEditingController(text: zone?.latitude.toString() ?? '0');
    final lngCtrl = TextEditingController(text: zone?.longitude.toString() ?? '0');
    final altCtrl = TextEditingController(text: zone?.altitude ?? '');
    final descCtrl = TextEditingController(text: zone?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isEdit ? '编辑区域' : '新增区域', style: const TextStyle(color: AppColors.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('区域名称 *', nameCtrl),
              _dialogField('区域编码 *', codeCtrl),
              _dialogField('纬度', latCtrl, keyboardType: TextInputType.number),
              _dialogField('经度', lngCtrl, keyboardType: TextInputType.number),
              _dialogField('海拔', altCtrl),
              _dialogField('描述', descCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                return;
              }
              final data = {
                'zone_name': nameCtrl.text.trim(),
                'zone_code': codeCtrl.text.trim(),
                'latitude': double.tryParse(latCtrl.text) ?? 0,
                'longitude': double.tryParse(lngCtrl.text) ?? 0,
                'altitude': altCtrl.text.trim(),
                'description': descCtrl.text.trim(),
              };
              try {
                if (isEdit) {
                  await ref.read(weatherActionsProvider.notifier).updateZone(zone.id, data);
                } else {
                  await ref.read(weatherActionsProvider.notifier).createZone(data);
                }
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('保存', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  void _deleteZone(WeatherZone z) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认删除', style: TextStyle(color: AppColors.text)),
        content: Text('删除区域「${z.zoneName}」？', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(weatherActionsProvider.notifier).deleteZone(z.id);
    }
  }

  Widget _dialogField(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
        ),
      ),
    );
  }
}
