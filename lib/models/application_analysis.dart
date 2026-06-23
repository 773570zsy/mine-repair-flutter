/// 申请分析数据
class ApplicationAnalysis {
  final String period;
  final int totalCount;
  final List<TypeCount> byType;
  final List<TrendPoint> trend;
  final List<VehicleRank> vehicleRanking;

  ApplicationAnalysis({
    required this.period,
    required this.totalCount,
    required this.byType,
    required this.trend,
    required this.vehicleRanking,
  });

  factory ApplicationAnalysis.fromJson(Map<String, dynamic> json) {
    return ApplicationAnalysis(
      period: json['period']?.toString() ?? 'month',
      totalCount: json['totalCount'] ?? 0,
      byType: (json['byType'] as List<dynamic>? ?? [])
          .map((e) => TypeCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      trend: (json['trend'] as List<dynamic>? ?? [])
          .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      vehicleRanking: (json['vehicleRanking'] as List<dynamic>? ?? [])
          .map((e) => VehicleRank.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TypeCount {
  final String vehicleType;
  final int count;
  final double percentage;

  TypeCount({
    required this.vehicleType,
    required this.count,
    required this.percentage,
  });

  factory TypeCount.fromJson(Map<String, dynamic> json) {
    return TypeCount(
      vehicleType: json['vehicle_type']?.toString() ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TrendPoint {
  final String label;
  final int count;
  final Map<String, int> types;

  TrendPoint({
    required this.label,
    required this.count,
    required this.types,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    final typesRaw = json['types'] as Map<String, dynamic>? ?? {};
    final types = typesRaw.map((k, v) => MapEntry(k, (v as num).toInt()));
    return TrendPoint(
      label: json['label']?.toString() ?? '',
      count: json['count'] ?? 0,
      types: types,
    );
  }
}

class VehicleRank {
  final String plateNumber;
  final String vehicleType;
  final int count;

  VehicleRank({
    required this.plateNumber,
    required this.vehicleType,
    required this.count,
  });

  factory VehicleRank.fromJson(Map<String, dynamic> json) {
    return VehicleRank(
      plateNumber: json['plate_number']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? '',
      count: json['count'] ?? 0,
    );
  }

  String get display => '$plateNumber ($vehicleType)';
  String get countLabel => '${count}次';
}
