/// 天气区域
class WeatherZone {
  final int id;
  final String zoneName;
  final String zoneCode;
  final double latitude;
  final double longitude;
  final String? altitude;
  final String? description;
  final int status;

  WeatherZone({
    required this.id,
    required this.zoneName,
    required this.zoneCode,
    this.latitude = 0,
    this.longitude = 0,
    this.altitude,
    this.description,
    this.status = 1,
  });

  factory WeatherZone.fromJson(Map<String, dynamic> json) {
    return WeatherZone(
      id: json['id'] ?? 0,
      zoneName: json['zone_name']?.toString() ?? '',
      zoneCode: json['zone_code']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0,
      altitude: json['altitude']?.toString(),
      description: json['description']?.toString(),
      status: json['status'] ?? 1,
    );
  }
}

/// 天气数据读数
class WeatherData {
  final String dataType;
  final double value;
  final String? unit;
  final String? recordedAt;

  WeatherData({
    required this.dataType,
    required this.value,
    this.unit,
    this.recordedAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      dataType: json['data_type']?.toString() ?? '',
      value: double.tryParse(json['value']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString(),
      recordedAt: json['recorded_at']?.toString(),
    );
  }
}

/// 天气预警
class WeatherWarning {
  final int id;
  final int zoneId;
  final String weatherType;
  final String level; // red/orange/yellow/blue
  final String? description;
  final String status; // active/acknowledged/resolved
  final String? zoneName;
  final String? zoneCode;
  final String? createdAt;
  final String? resolvedAt;

  WeatherWarning({
    required this.id,
    required this.zoneId,
    required this.weatherType,
    required this.level,
    this.description,
    this.status = 'active',
    this.zoneName,
    this.zoneCode,
    this.createdAt,
    this.resolvedAt,
  });

  factory WeatherWarning.fromJson(Map<String, dynamic> json) {
    return WeatherWarning(
      id: json['id'] ?? 0,
      zoneId: json['zone_id'] ?? 0,
      weatherType: json['weather_type']?.toString() ?? '',
      level: json['level']?.toString() ?? 'blue',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'active',
      zoneName: json['zone_name']?.toString(),
      zoneCode: json['zone_code']?.toString(),
      createdAt: json['created_at']?.toString(),
      resolvedAt: json['resolved_at']?.toString(),
    );
  }
}

/// 仪表盘区域数据
class WeatherDashboardZone {
  final WeatherZone zone;
  final List<WeatherData> latestData;
  final List<WeatherWarning> warnings;
  final int warningCount;
  final bool hasRedWarning;

  WeatherDashboardZone({
    required this.zone,
    this.latestData = const [],
    this.warnings = const [],
    this.warningCount = 0,
    this.hasRedWarning = false,
  });

  factory WeatherDashboardZone.fromJson(Map<String, dynamic> json) {
    final zoneJson = json['zone'] as Map<String, dynamic>;
    return WeatherDashboardZone(
      zone: WeatherZone.fromJson(zoneJson),
      latestData: (json['latestData'] as List<dynamic>?)
          ?.map((e) => WeatherData.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      warnings: (json['warnings'] as List<dynamic>?)
          ?.map((e) => WeatherWarning.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      warningCount: json['warningCount'] ?? 0,
      hasRedWarning: json['hasRedWarning'] ?? false,
    );
  }

  /// 按类型查找最新数据
  double? getReading(String type) {
    for (final d in latestData) {
      if (d.dataType == type) return d.value;
    }
    return null;
  }

  /// 天气图标
  String get weatherIcon {
    final temp = getReading('temperature') ?? 20;
    final rain = getReading('rainfall') ?? 0;
    final wind = getReading('wind_speed') ?? 0;
    if (rain > 5) return '🌧️';
    if (rain > 1) return '🌦️';
    if (wind > 30) return '🌬️';
    if (temp < 0) return '❄️';
    if (temp < 10) return '⛅';
    return '☀️';
  }
}

/// 天气仪表盘
class WeatherDashboard {
  final List<WeatherDashboardZone> zones;
  final List<WeatherWarning> activeWarnings;
  final WeatherSummary summary;

  WeatherDashboard({
    this.zones = const [],
    this.activeWarnings = const [],
    required this.summary,
  });

  factory WeatherDashboard.fromJson(Map<String, dynamic> json) {
    return WeatherDashboard(
      zones: (json['zones'] as List<dynamic>?)
          ?.map((e) => WeatherDashboardZone.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      activeWarnings: (json['activeWarnings'] as List<dynamic>?)
          ?.map((e) => WeatherWarning.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      summary: WeatherSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class WeatherSummary {
  final int totalActive;
  final int redCount;
  final int orangeCount;

  WeatherSummary({
    this.totalActive = 0,
    this.redCount = 0,
    this.orangeCount = 0,
  });

  factory WeatherSummary.fromJson(Map<String, dynamic> json) {
    return WeatherSummary(
      totalActive: json['totalActive'] ?? 0,
      redCount: json['redCount'] ?? 0,
      orangeCount: json['orangeCount'] ?? 0,
    );
  }
}

/// 预警阈值
class WeatherThreshold {
  final int id;
  final String weatherType;
  final String level;
  final double thresholdValue;
  final String dataType;
  final String comparison;

  WeatherThreshold({
    required this.id,
    required this.weatherType,
    required this.level,
    required this.thresholdValue,
    required this.dataType,
    this.comparison = '>=',
  });

  factory WeatherThreshold.fromJson(Map<String, dynamic> json) {
    return WeatherThreshold(
      id: json['id'] ?? 0,
      weatherType: json['weather_type']?.toString() ?? '',
      level: json['level']?.toString() ?? 'blue',
      thresholdValue: double.tryParse(json['threshold_value']?.toString() ?? '0') ?? 0,
      dataType: json['data_type']?.toString() ?? '',
      comparison: json['comparison']?.toString() ?? '>=',
    );
  }
}

/// 天气类型/等级标签映射
const weatherLabels = {
  'rainstorm': '暴雨', 'thunderstorm': '雷电', 'strong_wind': '大风',
  'snowstorm': '暴雪', 'sandstorm': '沙尘暴', 'low_visibility': '大雾/低能见度',
};

const weatherIcons = {
  'rainstorm': '🌧️', 'thunderstorm': '⛈️', 'strong_wind': '💨',
  'snowstorm': '🌨️', 'sandstorm': '🌪️', 'low_visibility': '🌫️',
};

const levelLabels = {'red': '红色', 'orange': '橙色', 'yellow': '黄色', 'blue': '蓝色'};
const levelEmoji = {'red': '🔴', 'orange': '🟠', 'yellow': '🟡', 'blue': '🔵'};
