import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/weather.dart';
import '../../providers/weather_provider.dart';

import '../../config/color_constants.dart';

class WeatherWarningListPage extends ConsumerWidget {
  const WeatherWarningListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warningsAsync = ref.watch(weatherWarningsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('预警记录'),
        backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
      ),
      body: warningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
        data: (warnings) {
          if (warnings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done, size: 48, color: AppColors.text2),
                  SizedBox(height: 10),
                  Text('暂无预警记录', style: TextStyle(color: AppColors.text2, fontSize: 15)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(weatherWarningsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: warnings.length,
              itemBuilder: (_, i) => _buildCard(context, warnings[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, WeatherWarning w) {
    final color = _levelColor(w.level);
    final statusLabel = w.status == 'active' ? '活跃' : (w.status == 'acknowledged' ? '已确认' : '已解除');
    final statusColor = w.status == 'active' ? AppColors.danger : (w.status == 'acknowledged' ? AppColors.warning : AppColors.success);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: w.status == 'active' ? color.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/weather/warning/${w.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(weatherIcons[w.weatherType] ?? '⚠️', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weatherLabels[w.weatherType] ?? w.weatherType,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                      if (w.zoneName != null)
                        Text('🏔️ ${w.zoneName}', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text('${levelEmoji[w.level] ?? ''} ${levelLabels[w.level] ?? w.level}',
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                    Text(w.createdAt?.substring(0, 10) ?? '', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                  ],
                ),
              ],
            ),
            if (w.description != null && w.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(w.description!, style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor)),
                ),
                const Text('详情 →', style: TextStyle(fontSize: 11, color: AppColors.gold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'red': return AppColors.danger;
      case 'orange': return AppColors.warning;
      case 'yellow': return const Color(0xFFd4a017);
      case 'blue': return const Color(0xFF4a90d9);
      default: return AppColors.text2;
    }
  }
}
