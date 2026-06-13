import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/weather.dart';
import '../../providers/auth_provider.dart';
import '../../providers/weather_provider.dart';

import '../../config/color_constants.dart';

class WeatherDashboardPage extends ConsumerWidget {
  const WeatherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(weatherDashboardProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('矿区天气预警'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.place, color: AppColors.gold, size: 20),
              tooltip: '区域管理',
              onPressed: () => context.push('/weather/zones'),
            ),
            IconButton(
              icon: const Icon(Icons.tune, color: AppColors.gold, size: 20),
              tooltip: '阈值配置',
              onPressed: () => context.push('/weather/thresholds'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.list_alt, color: AppColors.text2, size: 20),
            tooltip: '预警记录',
            onPressed: () => context.push('/weather/warnings'),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
        data: (d) {
          if (d == null) {
            return const Center(child: Text('暂无天气数据', style: TextStyle(color: AppColors.text2)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(weatherDashboardProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 预警汇总
                  if (d.summary.totalActive > 0) _buildSummaryBar(d.summary),
                  if (d.summary.totalActive > 0) const SizedBox(height: 12),

                  // 区域卡片
                  ...d.zones.map((z) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildZoneCard(context, z),
                  )),

                  if (d.zones.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('暂无矿区区域', style: TextStyle(color: AppColors.text2)))),

                  // 预警记录入口
                  const SizedBox(height: 8),
                  _buildSection(
                    '预警记录',
                    trailing: GestureDetector(
                      onTap: () => context.push('/weather/warnings'),
                      child: const Text('查看全部 →', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                    ),
                    child: d.activeWarnings.isEmpty
                      ? const Padding(padding: EdgeInsets.all(16), child: Text('✅ 暂无活跃预警', style: TextStyle(color: AppColors.text2)))
                      : Column(
                          children: d.activeWarnings.take(3).map((w) => _buildWarningRow(context, w)).toList(),
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 预警汇总条 ====================

  Widget _buildSummaryBar(WeatherSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('${s.totalActive}个活跃预警', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(width: 12),
          _badge('🔴 ${s.redCount}', AppColors.danger),
          const SizedBox(width: 6),
          _badge('🟠 ${s.orangeCount}', AppColors.warning),
        ],
      ),
    );
  }

  // ==================== 区域卡片 ====================

  Widget _buildZoneCard(BuildContext context, WeatherDashboardZone z) {
    final borderColor = z.hasRedWarning ? AppColors.danger : (z.warningCount > 0 ? AppColors.warning : AppColors.border);
    final temp = z.getReading('temperature');
    final humidity = z.getReading('humidity');
    final wind = z.getReading('wind_speed');
    final windGust = z.getReading('wind_gust');
    final rain = z.getReading('rainfall');
    final snow = z.getReading('snowfall');
    final pressure = z.getReading('pressure');
    final visibility = z.getReading('visibility');
    final cloud = z.getReading('cloud_cover');
    final hasData = z.latestData.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: z.hasRedWarning ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('🏔️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(z.zone.zoneName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                    if (z.zone.altitude != null)
                      Text(z.zone.altitude!, style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                  ],
                ),
              ),
              if (z.zone.latitude != 0 || z.zone.longitude != 0)
                Text('🧭 ${z.zone.latitude},${z.zone.longitude}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
            ],
          ),
          const SizedBox(height: 10),

          // 天气数据区
          if (hasData)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧：图标 + 温度大字
                Text(z.weatherIcon, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 8),
                Text(
                  temp != null ? '${temp.toStringAsFixed(0)}°' : '--',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.gold),
                ),
                const SizedBox(width: 16),
                // 右侧：详细数据（全字段，和3000一致）
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (humidity != null) _dataChip('💧', '湿度 ${humidity.toStringAsFixed(0)}%'),
                      if (wind != null) _windChip(wind, windGust),
                      if (rain != null) _dataChip('🌧', '降雨 ${rain.toStringAsFixed(0)}mm/h'),
                      if (snow != null) _dataChip('🌨', '降雪 ${snow.toStringAsFixed(0)}mm/h'),
                      if (pressure != null) _dataChip('📊', '气压 ${pressure.toStringAsFixed(1)}hPa'),
                      if (visibility != null) _dataChip('👁', '能见度 ${visibility >= 1000 ? '${(visibility/1000).toStringAsFixed(1)}km' : '${visibility.toStringAsFixed(0)}m'}'),
                      if (cloud != null) _dataChip('☁', '云量 ${cloud.toStringAsFixed(0)}%'),
                    ],
                  ),
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: Text('暂无实时数据', style: TextStyle(fontSize: 12, color: AppColors.text2))),
            ),

          // 预警标签
          if (z.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: z.warnings.map((w) => _warningTag(context, w)).toList(),
            ),
          ] else
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('✅ 无预警', style: TextStyle(fontSize: 10, color: AppColors.success)),
            ),
        ],
      ),
    );
  }

  Widget _dataChip(String icon, String text) {
    return Text('$icon $text', style: const TextStyle(fontSize: 12, color: AppColors.text2));
  }

  Widget _windChip(double speed, double? gust) {
    final desc = speed < 12 ? '微风' : (speed < 24 ? '大风' : '暴风');
    var text = '🌬 风速 ${speed.toStringAsFixed(1)}km/h $desc';
    if (gust != null && gust > 0) {
      text += ' 阵风${gust.toStringAsFixed(0)}km/h';
    }
    return Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2));
  }

  Widget _warningTag(BuildContext context, WeatherWarning w) {
    final color = _levelColor(w.level);
    return GestureDetector(
      onTap: () => context.push('/weather/warning/${w.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          '${levelEmoji[w.level] ?? ''} ${weatherLabels[w.weatherType] ?? w.weatherType}',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ==================== 预警记录区 ====================

  Widget _buildSection(String title, {Widget? trailing, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildWarningRow(BuildContext context, WeatherWarning w) {
    final color = _levelColor(w.level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => context.push('/weather/warning/${w.id}'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(levelLabels[w.level] ?? w.level, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${w.zoneName ?? ''} ${weatherLabels[w.weatherType] ?? w.weatherType}',
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ),
            Text(w.createdAt?.substring(0, 10) ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
