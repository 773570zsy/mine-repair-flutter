import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/maintenance.dart';
import '../../providers/maintenance_provider.dart';
import '../../config/color_constants.dart';

class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(maintenanceStatusListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('保养管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.build_circle, size: 48, color: AppColors.text2),
              SizedBox(height: 8),
              Text('暂无车辆', style: TextStyle(color: AppColors.text2)),
            ]));
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async => ref.invalidate(maintenanceStatusListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: list.length,
              itemBuilder: (_, i) => _buildCard(context, list[i]),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'overdue': return AppColors.danger;
      case 'soon': return AppColors.warning;
      case 'normal': return AppColors.success;
      default: return AppColors.text2;
    }
  }

  Widget _buildCard(BuildContext context, MaintenanceStatus m) {
    final sc = _statusColor(m.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: m.isAlert ? sc.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 头部
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.vehicleDisplay, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            if (m.model != null && m.model!.isNotEmpty)
              Text(m.model!, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: sc.withValues(alpha: 0.3))),
            child: Text(m.statusLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sc)),
          ),
        ]),

        const SizedBox(height: 8),

        // 保养进度条
        if (m.status != 'none' && m.maintenanceIntervalHours > 0) ...[
          Row(children: [
            const Text('保养进度', style: TextStyle(fontSize: 11, color: AppColors.text2)),
            const SizedBox(width: 8),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ((m.currentHours - (m.nextMaintenanceHours - m.maintenanceIntervalHours)) / m.maintenanceIntervalHours).clamp(0.0, 1.2),
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(m.status == 'overdue' ? AppColors.danger : m.status == 'soon' ? AppColors.warning : AppColors.success),
                minHeight: 6,
              ),
            )),
          ]),
          const SizedBox(height: 4),
        ],

        // 数据行
        Row(children: [
          _chip(Icons.speed, '当前 ${m.currentHours.toStringAsFixed(0)}h'),
          const SizedBox(width: 8),
          _chip(Icons.settings, '周期 ${m.maintenanceIntervalHours.toStringAsFixed(0)}h'),
          const SizedBox(width: 8),
          _chip(Icons.flag, '下次 ${m.nextMaintenanceHours.toStringAsFixed(0)}h'),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          _chip(
            m.status == 'overdue' ? Icons.warning_amber : m.status == 'soon' ? Icons.schedule : Icons.check_circle,
            m.remainingDisplay,
            color: sc,
          ),
          if (m.lastMaintenanceDate != null && m.lastMaintenanceDate!.isNotEmpty) ...[
            const SizedBox(width: 8),
            _chip(Icons.history, '上次 ${m.lastMaintenanceDate!.substring(0, 10)}'),
          ],
        ]),

        const SizedBox(height: 8),

        // 操作按钮
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton.icon(
            onPressed: () => _showHistory(context, m.vehicleId, m.plateNumber),
            icon: const Icon(Icons.history, size: 14),
            label: const Text('历史', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text2,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showRecordDialog(context, m),
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: const Text('记录保养', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color ?? AppColors.text2),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 11, color: color ?? AppColors.text2)),
    ]);
  }

  // ==================== 记录保养弹窗 ====================

  void _showRecordDialog(BuildContext context, MaintenanceStatus m) {
    final dateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));
    final hoursCtrl = TextEditingController(text: m.currentHours > 0 ? m.currentHours.toStringAsFixed(0) : '');
    final kmCtrl = TextEditingController(text: m.currentKm > 0 ? m.currentKm.toString() : '');
    final descCtrl = TextEditingController();
    final operatorCtrl = TextEditingController();
    String maintType = 'regular';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('记录保养 — ${m.plateNumber}', style: const TextStyle(color: AppColors.text, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _field('保养日期', dateCtrl, hint: 'YYYY-MM-DD'),
              const SizedBox(height: 10),
              _field('当前工时 (h)', hoursCtrl, hint: '发动机小时数', keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _field('当前公里数 (km)', kmCtrl, hint: '里程表读数', keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              const Text('保养类型', style: TextStyle(fontSize: 12, color: AppColors.text2)),
              const SizedBox(height: 4),
              _typeChip('常规保养', 'regular', maintType, () => setDialogState(() => maintType = 'regular')),
              const SizedBox(height: 10),
              _field('保养内容', descCtrl, hint: '更换机油滤芯、液压油等'),
              const SizedBox(height: 10),
              _field('操作人', operatorCtrl, hint: '操作人员姓名'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
            ElevatedButton(
              onPressed: () async {
                final date = dateCtrl.text.trim();
                if (date.isEmpty) return;
                Navigator.pop(context);

                try {
                  final actions = ref.read(maintenanceActionsProvider);
                  await actions.record(
                    vehicleId: m.vehicleId,
                    maintenanceDate: date,
                    currentHours: double.tryParse(hoursCtrl.text.trim()),
                    currentKm: int.tryParse(kmCtrl.text.trim()),
                    maintenanceType: maintType,
                    description: descCtrl.text.trim(),
                    operatorName: operatorCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('保养记录已保存，下次保养工时已自动更新'), backgroundColor: AppColors.success),
                    );
                    ref.invalidate(maintenanceStatusListProvider);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
              child: const Text('确认保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.border, fontSize: 12),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    ]);
  }

  Widget _typeChip(String label, String value, String current, VoidCallback onTap) {
    final active = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surface2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? AppColors.gold : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: active ? AppColors.bg : AppColors.text2)),
      ),
    );
  }

  // ==================== 保养历史弹窗 ====================

  void _showHistory(BuildContext context, int vehicleId, String plate) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(children: [
                const Icon(Icons.history, color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Text('$plate 保养历史', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.text2), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Consumer(
              builder: (_, WidgetRef ref, __) {
                final recordsAsync = ref.watch(maintenanceRecordsProvider(vehicleId));
                return recordsAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.gold)),
                  error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: const TextStyle(color: AppColors.danger))),
                  data: (records) {
                    if (records.isEmpty) {
                      return const Padding(padding: EdgeInsets.all(24), child: Text('暂无保养记录', style: TextStyle(color: AppColors.text2)));
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(10),
                        itemCount: records.length,
                        itemBuilder: (_, i) {
                          final r = records[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(r.maintenanceDate.length >= 10 ? r.maintenanceDate.substring(0, 10) : r.maintenanceDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                                  child: Text(r.typeLabel, style: const TextStyle(fontSize: 10, color: AppColors.gold)),
                                ),
                                const Spacer(),
                                if (r.cost > 0)
                                  Text('¥${r.cost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500)),
                              ]),
                              if (r.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(r.description, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                              ],
                              const SizedBox(height: 2),
                              Text('工时: ${r.currentHours.toStringAsFixed(0)}h${r.currentKm > 0 ? '  |  公里: ${r.currentKm}km' : ''}  |  操作人: ${r.operatorName.isNotEmpty ? r.operatorName : "-"}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                            ]),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
