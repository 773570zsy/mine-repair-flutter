/// 日常点检记录（早检 + 晚检）
class InspectionRecord {
  final int id;
  final int vehicleId;
  final int driverId;
  final String inspectionDate;

  // 早检字段
  final String? oilLevel;
  final String? coolantLevel;
  final String? appearance;
  final String? tireCondition;
  final String? toolkitCheck;
  final String? mentalState;
  final String? ppeWearing;
  final int? bloodPressureHigh;
  final int? bloodPressureLow;
  final String? overallStatus;
  final String? abnormalDesc;
  final String? notes;
  final int? engineHours;

  // 晚检字段
  final double? startHours;
  final double? endHours;
  final double? fuelAmount;
  final String? attendanceSymbol;
  final String? parkingLocation;
  final double? startKm;
  final double? currentKm;

  // 照片
  final List<String> photos;

  // JOIN 字段
  final String? plateNumber;
  final String? vehicleType;
  final String? driverName;

  final String? createdAt;
  final String? updatedAt;

  InspectionRecord({
    required this.id,
    required this.vehicleId,
    required this.driverId,
    required this.inspectionDate,
    this.oilLevel,
    this.coolantLevel,
    this.appearance,
    this.tireCondition,
    this.toolkitCheck,
    this.mentalState,
    this.ppeWearing,
    this.bloodPressureHigh,
    this.bloodPressureLow,
    this.overallStatus,
    this.abnormalDesc,
    this.notes,
    this.engineHours,
    this.startHours,
    this.endHours,
    this.fuelAmount,
    this.attendanceSymbol,
    this.parkingLocation,
    this.startKm,
    this.currentKm,
    this.photos = const [],
    this.plateNumber,
    this.vehicleType,
    this.driverName,
    this.createdAt,
    this.updatedAt,
  });

  double get workHours {
    if (startHours != null && endHours != null && endHours! > startHours!) {
      return endHours! - startHours!;
    }
    return 0;
  }

  String get mentalStateLabel => mentalState == 'abnormal' ? '不正常' : '正常';
  String get ppeWearingLabel => ppeWearing == 'missing' ? '缺失' : '齐全';
  String get bloodPressureDisplay =>
    (bloodPressureHigh != null && bloodPressureHigh! > 0)
      ? '$bloodPressureHigh/$bloodPressureLow' : '-';

  factory InspectionRecord.fromJson(Map<String, dynamic> json) {
    List<String> parsePhotos(dynamic p) {
      if (p is List) return p.map((e) => e.toString()).toList();
      if (p is String && p.isNotEmpty) {
        try {
          return List<String>.from(
            (RegExp(r'\[(.*)\]').firstMatch(p)?.group(1) ?? '')
                .split(',')
                .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((s) => s.isNotEmpty),
          );
        } catch (_) {}
      }
      return [];
    }

    return InspectionRecord(
      id: json['id'] as int? ?? 0,
      vehicleId: json['vehicle_id'] as int? ?? 0,
      driverId: json['driver_id'] as int? ?? 0,
      inspectionDate: (json['inspection_date'] ?? '') as String,
      oilLevel: json['oil_level'] as String?,
      coolantLevel: json['coolant_level'] as String?,
      appearance: json['appearance'] as String?,
      tireCondition: json['tire_condition'] as String?,
      toolkitCheck: json['toolkit_check'] as String?,
      mentalState: json['mental_state'] as String?,
      ppeWearing: json['ppe_wearing'] as String?,
      bloodPressureHigh: json['blood_pressure_high'] as int?,
      bloodPressureLow: json['blood_pressure_low'] as int?,
      overallStatus: json['overall_status'] as String?,
      abnormalDesc: json['abnormal_desc'] as String?,
      notes: json['notes'] as String?,
      engineHours: json['engine_hours'] as int?,
      startHours: (json['start_hours'] as num?)?.toDouble(),
      endHours: (json['end_hours'] as num?)?.toDouble(),
      fuelAmount: (json['fuel_amount'] as num?)?.toDouble(),
      attendanceSymbol: json['attendance_symbol'] as String?,
      parkingLocation: json['parking_location'] as String?,
      startKm: (json['start_km'] as num?)?.toDouble(),
      currentKm: (json['current_km'] as num?)?.toDouble(),
      photos: parsePhotos(json['photos']),
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      driverName: json['driver_name'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// 今日概况
class TodaySummary {
  final String date;
  final int totalVehicles;
  final int inspectedCount;
  final int uninspectedCount;
  final List<UninspectedVehicle> uninspected;

  TodaySummary({
    required this.date,
    required this.totalVehicles,
    required this.inspectedCount,
    required this.uninspectedCount,
    required this.uninspected,
  });

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    final list = (json['uninspected'] as List<dynamic>? ?? [])
        .map((v) => UninspectedVehicle.fromJson(v as Map<String, dynamic>))
        .toList();
    return TodaySummary(
      date: (json['date'] ?? '') as String,
      totalVehicles: json['totalVehicles'] as int? ?? 0,
      inspectedCount: json['inspectedCount'] as int? ?? 0,
      uninspectedCount: json['uninspectedCount'] as int? ?? list.length,
      uninspected: list,
    );
  }
}

class UninspectedVehicle {
  final int id;
  final String plateNumber;
  final String? vehicleType;
  final String? driverName;

  UninspectedVehicle({
    required this.id,
    required this.plateNumber,
    this.vehicleType,
    this.driverName,
  });

  factory UninspectedVehicle.fromJson(Map<String, dynamic> json) {
    return UninspectedVehicle(
      id: json['id'] as int? ?? 0,
      plateNumber: (json['plate_number'] ?? '') as String,
      vehicleType: json['vehicle_type'] as String?,
      driverName: json['driver_name'] as String?,
    );
  }
}

/// 工时统计
class WorkHoursSummary {
  final String driverName;
  final double totalHours;
  final double totalFuel;
  final double totalKm;
  final int days;
  final List<dynamic> records;

  WorkHoursSummary({
    required this.driverName,
    required this.totalHours,
    required this.totalFuel,
    required this.totalKm,
    required this.days,
    required this.records,
  });

  factory WorkHoursSummary.fromJson(Map<String, dynamic> json) {
    return WorkHoursSummary(
      driverName: (json['driver_name'] ?? '') as String,
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0,
      totalFuel: (json['total_fuel'] as num?)?.toDouble() ?? 0,
      totalKm: (json['total_km'] as num?)?.toDouble() ?? 0,
      days: json['days'] as int? ?? 0,
      records: (json['records'] as List<dynamic>?) ?? [],
    );
  }
}
