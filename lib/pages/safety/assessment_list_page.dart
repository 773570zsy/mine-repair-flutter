import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/safety_provider.dart';
import '../../models/assessment.dart';

import '../../config/color_constants.dart';

class AssessmentListPage extends ConsumerWidget {
  const AssessmentListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(assessmentListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('考核通报'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => ref.invalidate(assessmentListProvider),
        child: assessmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('加载失败', style: TextStyle(color: AppColors.danger)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(assessmentListProvider),
                  child: const Text('重试', style: TextStyle(color: AppColors.gold)),
                ),
              ],
            ),
          ),
          data: (assessments) {
            if (assessments.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 48, color: AppColors.text2),
                    SizedBox(height: 8),
                    Text('暂无通报记录', style: TextStyle(color: AppColors.text2, fontSize: 13)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: assessments.length,
              itemBuilder: (context, i) => _AssessmentCard(assessment: assessments[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => context.push('/safety/assessment/issue'),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final Assessment assessment;
  const _AssessmentCard({required this.assessment});

  Color _typeColor() {
    switch (assessment.assessType) {
      case '表扬': return AppColors.success;
      case '通报': return AppColors.warning;
      case '警告':
      case '处罚': return AppColors.danger;
      default: return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/safety/assessment/detail/${assessment.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(assessment.assessNo,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _typeColor().withValues(alpha: 0.3)),
                  ),
                  child: Text(assessment.assessType,
                      style: TextStyle(fontSize: 10, color: _typeColor(), fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Text(
                  assessment.createdAt.length >= 10
                      ? assessment.createdAt.substring(0, 10)
                      : '',
                  style: const TextStyle(fontSize: 11, color: AppColors.text2),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(assessment.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('被考核人：${assessment.targetName ?? '-'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                const Spacer(),
                Text('下发人：${assessment.issuerName ?? '-'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
