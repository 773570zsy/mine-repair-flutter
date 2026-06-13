import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/color_constants.dart';
import '../providers/hazard_provider.dart';
import '../providers/safety_provider.dart';
import '../models/hazard.dart';
import '../models/assessment.dart';

/// 隐患通报公示板 — 悬浮按钮弹出，全屏 Modal
class BulletinBoard extends ConsumerWidget {
  const BulletinBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazardsAsync = ref.watch(hazardListProvider(null));
    final assessmentsAsync = ref.watch(assessmentListProvider);

    return Dialog.fullscreen(
      backgroundColor: AppColors.bg,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: const Text('隐患通报公示板'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.text,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: const TabBar(
              indicatorColor: AppColors.gold,
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.text2,
              tabs: const [
                Tab(text: '隐患'),
                Tab(text: '通报'),
                Tab(text: '已闭环'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _HazardTab(hazardsAsync, false),
              _AssessTab(assessmentsAsync),
              _HazardTab(hazardsAsync, true),
            ],
          ),
        ),
      ),
    );
  }
}

class _HazardTab extends ConsumerWidget {
  final AsyncValue<List<Hazard>> async;
  final bool closedOnly;
  const _HazardTab(this.async, this.closedOnly);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (_, _) => const Center(child: Text('加载失败', style: TextStyle(color: AppColors.danger))),
      data: (list) {
        final filtered = closedOnly
            ? list.where((h) => h.status == 'verified').toList()
            : list.toList();
        if (filtered.isEmpty) {
          return const Center(
            child: Text('暂无记录', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _hzCard(context, filtered[i]),
        );
      },
    );
  }

  Widget _hzCard(BuildContext context, Hazard h) {
    final sm = {'低': AppColors.success, '一般': AppColors.warning, '高': AppColors.danger, '紧急': AppColors.danger};
    final st = {'reported': '待指派', 'assigned': '已指派', 'rectifying': '整改中', 'completed': '待确认', 'verified': '已闭环'};
    return InkWell(
      onTap: () {
        // 关闭公示板 → 跳转隐患详情
        Navigator.of(context, rootNavigator: true).pop();
        context.push('/hazard/detail/${h.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(h.hazardNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: (sm[h.severity] ?? AppColors.text2).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(h.severity, style: TextStyle(fontSize: 10, color: sm[h.severity] ?? AppColors.text2, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Text(st[h.status] ?? h.status, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ]),
          const SizedBox(height: 4),
          Text(h.location.isNotEmpty ? h.location : '未指定', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          Text(h.description, style: const TextStyle(fontSize: 11, color: AppColors.text2), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (h.deadline.isNotEmpty) Text('期限: ${h.deadline}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
        ]),
      ),
    );
  }
}

class _AssessTab extends ConsumerWidget {
  final AsyncValue<List<Assessment>> async;
  const _AssessTab(this.async);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (_, _) => const Center(child: Text('加载失败', style: TextStyle(color: AppColors.danger))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('暂无通报记录', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: list.length,
          itemBuilder: (_, i) => _asCard(context, list[i]),
        );
      },
    );
  }

  Widget _asCard(BuildContext context, Assessment a) {
    final tc = {'表扬': AppColors.success, '通报': AppColors.warning, '警告': AppColors.danger, '处罚': AppColors.danger};
    return InkWell(
      onTap: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.push('/safety/assessment/detail/${a.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(a.assessNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: (tc[a.assessType] ?? AppColors.text2).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(a.assessType, style: TextStyle(fontSize: 10, color: tc[a.assessType] ?? AppColors.text2, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(a.title, style: const TextStyle(fontSize: 12, color: AppColors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
          Row(children: [
            Text(a.targetName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            const Spacer(),
            Text(a.createdAt.length >= 10 ? a.createdAt.substring(0, 10) : '', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
          ]),
        ]),
      ),
    );
  }
}
