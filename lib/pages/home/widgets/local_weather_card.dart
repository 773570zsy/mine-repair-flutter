import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/color_constants.dart';
import '../../../providers/local_weather_provider.dart';

/// 本地天气卡片 — 显示在首页顶部
/// GPS不可用时自动隐藏
class LocalWeatherCard extends ConsumerWidget {
  const LocalWeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(localWeatherProvider);

    return weatherAsync.when(
      loading: () => const SizedBox.shrink(), // 定位中不显示
      error: (e, _) {
        debugPrint('[LocalWeather] 获取失败: $e');
        return const SizedBox.shrink();
      },
      data: (w) {
        if (w == null) return const SizedBox.shrink(); // 无GPS不显示
        return _buildCard(context, w);
      },
    );
  }

  Widget _buildCard(BuildContext context, LocalWeather w) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: _weatherGradient(w.weatherIcon),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：城市名
          Row(
            children: [
              const Icon(Icons.location_on, size: 12, color: Colors.white70),
              const SizedBox(width: 3),
              Text(
                w.city,
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 第二行：图标+温度+描述/体感/湿度/风力 + 预报（右侧）
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(w.weatherIcon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 6),
              Text(
                '${w.temp}°',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300, color: Colors.white, height: 1.0),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(w.weatherDesc, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    const SizedBox(height: 2),
                    _infoText('体感${w.feelsLike}°  湿度${w.humidity}%'),
                    const SizedBox(height: 1),
                    _infoText(w.windDesc),
                  ],
                ),
              ),
              // 3天预报
              if (w.forecast.isNotEmpty)
                ...w.forecast.take(3).map((f) => Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _forecastCell(f),
                )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoText(String text) {
    return Text(text, style: const TextStyle(fontSize: 10, color: Colors.white60));
  }

  Widget _forecastCell(LocalForecast f) {
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.dayLabel, style: const TextStyle(fontSize: 9, color: Colors.white60)),
          Text(f.weatherIcon, style: const TextStyle(fontSize: 16)),
          Text(
            '${f.tempMax}°/${f.tempMin}°',
            style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// 根据天气图标选择背景渐变
  LinearGradient _weatherGradient(String icon) {
    // 雨天/雪天 → 蓝灰，晴天 → 暖调蓝，雷暴 → 深灰
    final isRain = icon.contains('🌧') || icon.contains('🌦');
    final isSnow = icon.contains('🌨') || icon.contains('❄');
    final isStorm = icon.contains('⛈');
    final isClear = icon.contains('☀') || icon.contains('🌤');

    if (isStorm) {
      return const LinearGradient(
        colors: [Color(0xFF3a3a4a), Color(0xFF2a2a3a)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      );
    }
    if (isRain || isSnow) {
      return const LinearGradient(
        colors: [Color(0xFF2a3a4a), Color(0xFF1a2a3a)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      );
    }
    if (isClear) {
      return const LinearGradient(
        colors: [Color(0xFF4a6a8a), Color(0xFF3a5a7a)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      );
    }
    // 默认多云
    return const LinearGradient(
      colors: [Color(0xFF3a4a5a), Color(0xFF2a3a4a)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    );
  }
}
