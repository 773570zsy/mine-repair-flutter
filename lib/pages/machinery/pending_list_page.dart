import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/export_helper.dart';
import '../../models/machinery.dart';
import '../../services/machinery_service.dart';
import '../../providers/machinery_provider.dart';
import '../../providers/repair_provider.dart';

import '../../config/color_constants.dart';

class PendingListPage extends ConsumerStatefulWidget {
  const PendingListPage({super.key});

  @override
  ConsumerState<PendingListPage> createState() => _PendingListPageState();
}

class _PendingListPageState extends ConsumerState<PendingListPage> {
  String _filterType = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(machineryPendingListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('待指派申请'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.assignment, size: 16, color: AppColors.gold),
            label: const Text('生成今日已指派', style: TextStyle(color: AppColors.gold, fontSize: 12)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: () => _showDailyReport(context),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (data) {
          final allList = (data['list'] as List<dynamic>? ?? [])
              .map((v) => MachineryApplication.fromJson(v as Map<String, dynamic>))
              .toList();
          final stats = MachineryStats.fromJson(data['stats'] as Map<String, dynamic>? ?? {});

          // 从车辆档案获取全部车型供筛选
          final vehicles = ref.watch(vehicleListProvider).valueOrNull ?? [];
          final types = vehicles.map((v) => v.vehicleType).where((t) => t.isNotEmpty).toSet().toList()..sort();

          final list = _filterType.isEmpty
              ? allList
              : allList.where((a) => a.vehicleType == _filterType).toList();

          return Column(children: [
            // 资源统计条
            _buildStatsBar(stats),

            // 筛选栏
            if (types.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppColors.surface,
                child: Row(children: [
                  const Icon(Icons.filter_list, size: 16, color: AppColors.gold),
                  const SizedBox(width: 6),
                  const Text('车辆类型：', style: TextStyle(fontSize: 13, color: AppColors.text2)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip('全部', _filterType.isEmpty, () => setState(() => _filterType = '')),
                        ...types.map((t) => _filterChip(t, _filterType == t, () => setState(() => _filterType = t))),
                      ]),
                    ),
                  ),
                ]),
              ),

            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('暂无待指派申请', style: TextStyle(color: AppColors.text2)))
                  : RefreshIndicator(
                      color: AppColors.gold,
                      onRefresh: () async { ref.invalidate(machineryPendingListProvider); },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) => _buildCard(context, list[i]),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.gold : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: active ? AppColors.bg : AppColors.text2, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildStatsBar(MachineryStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.surface,
      child: Row(children: [
        _statChip(Icons.directions_car, '车辆 ${stats.availableVehicles}/${stats.totalVehicles}', stats.availableVehicles > 0 ? AppColors.success : AppColors.danger),
        const SizedBox(width: 8),
        _statChip(Icons.person, '驾驶员 ${stats.availableDrivers}/${stats.totalDrivers}', stats.availableDrivers > 0 ? AppColors.success : AppColors.danger),
      ]),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildCard(BuildContext context, MachineryApplication app) {
    final urgencyColor = app.urgency == 'emergency' ? AppColors.danger : app.urgency == 'urgent' ? AppColors.warning : AppColors.text2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: app.urgency == 'emergency' ? AppColors.danger.withValues(alpha: 0.5) : AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(app.applicationNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
            child: Text(app.urgencyLabel, style: TextStyle(fontSize: 11, color: urgencyColor, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),
          Text(app.applicantDept, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _infoIcon(Icons.person, app.applicantName),
          const SizedBox(width: 12),
          _infoIcon(Icons.phone, app.applicantPhone),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          _infoIcon(Icons.build, app.vehicleType),
          const SizedBox(width: 12),
          _infoIcon(Icons.location_on, app.workLocation),
          if (app.workAltitude != null && app.workAltitude!.isNotEmpty) ...[
            const SizedBox(width: 12),
            _infoIcon(Icons.terrain, '${app.workAltitude}m'),
          ],
        ]),
        const SizedBox(height: 4),
        Row(children: [
          _infoIcon(Icons.access_time, '${app.scheduledStart} ~ ${app.scheduledEnd}'),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _infoIcon(Icons.work, app.workPurpose)),
        ]),
        if (app.isHazardous) ...[
          const SizedBox(height: 4),
          const Row(children: [
            Icon(Icons.warning_amber, size: 14, color: AppColors.danger),
            SizedBox(width: 4),
            Text('危险作业', style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500)),
          ]),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/machinery/assign/${app.id}'),
            icon: const Icon(Icons.assignment_turned_in, size: 16),
            label: const Text('指派'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          ),
        ),
      ]),
    );
  }

  Widget _infoIcon(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.text2),
      const SizedBox(width: 3),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Future<void> _showDailyReport(BuildContext context) async {
    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      final result = await MachineryService().generateDailyReport();
      final text = result['text']?.toString() ?? '暂无数据';
      final count = result['count'] ?? 0;

      if (mounted) Navigator.pop(context); // 关闭loading
      if (!mounted) return;

      if (kIsWeb) {
        // Web：直接触发下载
        downloadTextFile(text, '今日已指派工作安排.txt');
      }

      // 弹窗展示文本 + 复制按钮（全平台）
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(children: [
            const Icon(Icons.assignment, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text('今日已指派 ($count单)', style: const TextStyle(color: AppColors.text, fontSize: 16)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭', style: TextStyle(color: AppColors.text2)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板'), backgroundColor: AppColors.success),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('复制文本'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败: $e'), backgroundColor: AppColors.danger));
      }
    }
  }
}
