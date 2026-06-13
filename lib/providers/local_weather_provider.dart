import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';

/// 本地天气数据模型
class LocalWeather {
  final String city;
  final int temp;
  final int feelsLike;
  final int humidity;
  final int pressure;
  final String weatherDesc;
  final String weatherIcon;
  final String windDesc;
  final String windDir;
  final List<LocalForecast> forecast;

  LocalWeather({
    required this.city,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.pressure,
    required this.weatherDesc,
    required this.weatherIcon,
    required this.windDesc,
    required this.windDir,
    this.forecast = const [],
  });

  factory LocalWeather.fromJson(Map<String, dynamic> json) {
    final c = json['current'] as Map<String, dynamic>;
    final fList = (json['forecast'] as List<dynamic>?)
        ?.map((e) => LocalForecast.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return LocalWeather(
      city: json['city']?.toString() ?? '当前位置',
      temp: c['temp'] ?? 0,
      feelsLike: c['feelsLike'] ?? 0,
      humidity: c['humidity'] ?? 0,
      pressure: c['pressure'] ?? 0,
      weatherDesc: c['weatherDesc']?.toString() ?? '',
      weatherIcon: c['weatherIcon']?.toString() ?? '🌡️',
      windDesc: c['windDesc']?.toString() ?? '',
      windDir: c['windDir']?.toString() ?? '',
      forecast: fList,
    );
  }
}

class LocalForecast {
  final String dayLabel;
  final String weatherDesc;
  final String weatherIcon;
  final int tempMax;
  final int tempMin;
  final int precipProb;

  LocalForecast({
    required this.dayLabel,
    required this.weatherDesc,
    required this.weatherIcon,
    required this.tempMax,
    required this.tempMin,
    required this.precipProb,
  });

  factory LocalForecast.fromJson(Map<String, dynamic> json) {
    return LocalForecast(
      dayLabel: json['dayLabel']?.toString() ?? '',
      weatherDesc: json['weatherDesc']?.toString() ?? '',
      weatherIcon: json['weatherIcon']?.toString() ?? '🌡️',
      tempMax: json['tempMax'] ?? 0,
      tempMin: json['tempMin'] ?? 0,
      precipProb: json['precipProb'] ?? 0,
    );
  }
}

// ==================== Providers ====================

/// WeatherService 实例
final localWeatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

/// 本地天气 FutureProvider
/// 获取GPS坐标 → 调后端 /weather/local → 返回 LocalWeather
/// GPS不可用时降级用矿区默认坐标（驱龙选矿厂）
final localWeatherProvider = FutureProvider.autoDispose<LocalWeather?>((ref) async {
  double lat = 29.69;
  double lon = 91.61;

  try {
    // 1. 尝试获取GPS位置
    final hasPermission = await Geolocator.checkPermission();
    LocationPermission perm = hasPermission;
    if (hasPermission == LocationPermission.denied ||
        hasPermission == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        lat = position.latitude;
        lon = position.longitude;
      } catch (_) { /* GPS失败，用默认坐标 */ }
    }
  } catch (_) { /* 权限异常，用默认坐标 */ }

  // 2. 调后端（GPS成功用真实坐标，失败用默认坐标）
  try {
    final service = ref.read(localWeatherServiceProvider);
    final data = await service.getLocalWeather(lat, lon);
    if (data == null) return null;
    return LocalWeather.fromJson(data);
  } catch (_) {
    return null;
  }
});
