import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/machinery.dart';
import '../../providers/machinery_provider.dart';

import '../../config/color_constants.dart';

class MyApplicationsPage extends ConsumerWidget {
  const MyApplicationsPage({super.key});

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return AppColors.warning;
      case 'assigned':
      case 'in_progress': return const Color(0xFF2980b9);
      case 'completed':
      case 'early_completed': return AppColors.success;
      case 'cancelled': return AppColors.text2;
      default: return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMachineryApplicationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('我的申请'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.calculate_outlined, size: 20, color: AppColors.gold),
            tooltip: '费用统计',
            onPressed: () => context.push('/machinery/cost-stats'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('暂无申请记录', style: TextStyle(color: AppColors.text2)))
            : RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async => ref.invalidate(myMachineryApplicationsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _buildCard(context, list[i], ref),
                ),
              ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, MachineryApplication app, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => context.push('/machinery/detail/${app.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(app.applicationNo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
            _tag(app.statusLabel, _statusColor(app.status)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _infoIcon(Icons.category, app.vehicleType),
            const SizedBox(width: 12),
            _infoIcon(Icons.location_on, app.workLocation),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _infoIcon(Icons.access_time, app.workTimeDisplay),
            const SizedBox(width: 12),
            _infoIcon(Icons.flag, app.urgencyLabel),
          ]),
          if (app.isActive) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (app.vehicleDisplay != '未指派')
                Expanded(child: _infoIcon(Icons.directions_car, app.vehicleDisplay)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                onPressed: () => _earlyEnd(context, ref, app),
                icon: const Icon(Icons.stop_circle_outlined, size: 16, color: AppColors.danger),
                label: const Text('提前结束', style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            ]),
          ],
          if (app.isPending) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cancel(context, ref, app),
                icon: const Icon(Icons.close, size: 16, color: AppColors.text2),
                label: const Text('取消申请', style: TextStyle(color: AppColors.text2, fontSize: 12)),
              ),
            ),
          ],
          if (app.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(app.createdAt!.substring(0, 16), style: const TextStyle(fontSize: 10, color: AppColors.text2)),
            ),
        ]),
      ),
    );
  }

  Widget _infoIcon(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.text2),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
    ]);
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  void _earlyEnd(BuildContext context, WidgetRef ref, MachineryApplication app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认提前结束', style: TextStyle(color: AppColors.text)),
        content: Text('确认结束用车 "${app.applicationNo}" 吗？', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(machineryActionsProvider).earlyEnd(app.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用车已结束')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
  }

  void _cancel(BuildContext context, WidgetRef ref, MachineryApplication app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认取消', style: TextStyle(color: AppColors.text)),
        content: Text('确认取消申请 "${app.applicationNo}" 吗？', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('返回', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(machineryActionsProvider).cancelApplication(app.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF555), foregroundColor: Colors.white),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
  }
}
