import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/safety_provider.dart';
import '../../config/api_config.dart';

import '../../config/color_constants.dart';
import '../../widgets/photo_viewer.dart';

class AssessmentDetailPage extends ConsumerWidget {
  final int assessmentId;
  const AssessmentDetailPage({super.key, required this.assessmentId});

  String _photoUrl(String path) {
    if (path.startsWith('http')) return path;
    return ApiConfig.fileUrl(path);
  }

  Color _typeColor(String type) {
    switch (type) {
      case '表扬': return AppColors.success;
      case '通报': return AppColors.warning;
      case '警告':
      case '处罚': return AppColors.danger;
      default: return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(assessmentDetailProvider(assessmentId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('考核详情'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
        data: (assessment) {
          if (assessment == null) {
            return const Center(child: Text('记录不存在', style: TextStyle(color: AppColors.text2)));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本信息
                _section([
                  _infoRow('通报编号', assessment.assessNo),
                  _infoRow('考核类型', assessment.assessType, valueColor: _typeColor(assessment.assessType)),
                  _infoRow('标题', assessment.title),
                  _infoRow('被考核人', assessment.targetName ?? ''),
                  _infoRow('下发人', assessment.issuerName ?? ''),
                  _infoRow('下发时间', assessment.createdAt.length >= 16 ? assessment.createdAt.substring(0, 16) : assessment.createdAt),
                ]),
                const SizedBox(height: 10),

                // 内容
                _section([
                  _sectionTitle('考核内容'),
                  const SizedBox(height: 4),
                  Text(
                    assessment.content.isNotEmpty ? assessment.content : '无详细内容',
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                  ),
                ]),
                const SizedBox(height: 10),

                // 照片
                if (assessment.photos != null && assessment.photos!.isNotEmpty) ...[
                  (() {
                    final fullUrls = assessment.photos!.map((u) => _photoUrl(u)).toList();
                    return _section([
                      _sectionTitle('相关照片'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: fullUrls.asMap().entries.map((e) {
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PhotoViewer(images: fullUrls, initialIndex: e.key),
                            )),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(e.value, width: 80, height: 80, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 80, height: 80, color: AppColors.surface2,
                                  child: const Icon(Icons.broken_image, color: AppColors.text2, size: 24),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ]);
                  })(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2));
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? AppColors.text, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
