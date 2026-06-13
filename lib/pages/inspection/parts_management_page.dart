import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/part.dart';
import '../../providers/inspection_provider.dart';

import '../../config/color_constants.dart';

class PartsManagementPage extends ConsumerStatefulWidget {
  const PartsManagementPage({super.key});

  @override
  ConsumerState<PartsManagementPage> createState() => _PartsManagementPageState();
}

class _PartsManagementPageState extends ConsumerState<PartsManagementPage> {
  @override
  Widget build(BuildContext context) {
    final requisitionsAsync = ref.watch(partRequisitionsProvider(null));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('配件管理'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: requisitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (reqs) {
          if (reqs.isEmpty) {
            return const Center(child: Text('暂无领用记录', style: TextStyle(color: AppColors.text2)));
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async { ref.invalidate(partRequisitionsProvider(null)); },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reqs.length,
              itemBuilder: (ctx, i) => _buildReqCard(reqs[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReqCard(PartRequisition r) {
    Color statusColor;
    switch (r.status) {
      case 'pending': statusColor = AppColors.warning; break;
      case 'completed': statusColor = AppColors.success; break;
      case 'rejected': statusColor = AppColors.danger; break;
      default: statusColor = AppColors.text2;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.partName ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
            child: Text(r.statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _infoChip(Icons.person, r.userName ?? '-'),
          const SizedBox(width: 8),
          _infoChip(Icons.confirmation_number, '${r.quantity}个'),
          if (r.plateNumber != null) ...[const SizedBox(width: 8), _infoChip(Icons.directions_car, r.plateNumber!)],
          const Spacer(),
          if (r.createdAt != null) Text(r.createdAt!.substring(0, 16), style: const TextStyle(fontSize: 10, color: AppColors.text2)),
        ]),
        if (r.reason != null && r.reason!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('原因：${r.reason}', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        ],
        // 操作按钮
        if (r.isPending) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _confirmRequisition(r.id),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('确认出库', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rejectRequisition(r.id),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('驳回', style: TextStyle(fontSize: 12)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.text2),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
    ]);
  }

  Future<void> _confirmRequisition(int reqId) async {
    try {
      await ref.read(inspectionActionsProvider.notifier).confirmRequisition(reqId);
      ref.invalidate(partRequisitionsProvider(null));
      ref.invalidate(partsListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rejectRequisition(int reqId) async {
    try {
      await ref.read(inspectionActionsProvider.notifier).rejectRequisition(reqId);
      ref.invalidate(partRequisitionsProvider(null));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
