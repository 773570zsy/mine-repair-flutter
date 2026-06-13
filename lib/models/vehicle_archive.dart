/// 在编车辆档案
class VehicleArchive {
  final int id;
  final String plateNumber;
  final String? department;
  final String? vehicleType;
  final String? model;
  final String? manufactureDate;
  final String? purchaseDate;
  final String? vin;
  final String? insuranceExpiry;
  final String? inspectionDate;
  final int maintenanceInterval;        // 保养间隔（工时）
  final int nextMaintenanceHours;       // 下次保养工时
  final int maintenanceIntervalKm;      // 保养间隔（公里）
  final int nextMaintenanceKm;          // 下次保养公里
  final int currentKm;                  // 当前公里
  final double currentHours;            // 当前工时（来自晚检累加）
  final double hourlyRate;              // 小时单价（元/h）
  final bool hasBehaviorMonitor;
  final bool has360Camera;
  final double assetValue;               // 车辆资产净值（来自 vehicles 表）
  final List<String> photos;
  final String? vehicleStatus;          // 来自 vehicles 表
  final String? driverName;             // 当前驾驶员
  final String? createdAt;
  final String? updatedAt;

  VehicleArchive({
    required this.id,
    required this.plateNumber,
    this.department,
    this.vehicleType,
    this.model,
    this.manufactureDate,
    this.purchaseDate,
    this.vin,
    this.insuranceExpiry,
    this.inspectionDate,
    this.maintenanceInterval = 500,
    this.nextMaintenanceHours = 0,
    this.maintenanceIntervalKm = 0,
    this.nextMaintenanceKm = 0,
    this.currentKm = 0,
    this.currentHours = 0,
    this.hourlyRate = 0,
    this.hasBehaviorMonitor = false,
    this.has360Camera = false,
    this.assetValue = 0,
    this.photos = const [],
    this.vehicleStatus,
    this.driverName,
    this.createdAt,
    this.updatedAt,
  });

  factory VehicleArchive.fromJson(Map<String, dynamic> json) {
    List<String> photos = [];
    if (json['photos'] != null) {
      if (json['photos'] is List) {
        photos = (json['photos'] as List).map((e) => e.toString()).toList();
      } else if (json['photos'] is String) {
        try {
          photos = (json['photos'] as String).isNotEmpty ? [json['photos']] : [];
        } catch (_) {
          photos = [];
        }
      }
    }
    // Try to parse photos string as JSON array
    if (json['photos'] is String && (json['photos'] as String).startsWith('[')) {
      try {
        photos = (json['photos'] as String)
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .toList();
      } catch (_) {
        photos = [];
      }
    }

    return VehicleArchive(
      id: json['id'] ?? 0,
      plateNumber: json['plate_number']?.toString() ?? '',
      department: json['department']?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      model: json['model']?.toString(),
      manufactureDate: json['manufacture_date']?.toString(),
      purchaseDate: json['purchase_date']?.toString(),
      vin: json['vin']?.toString(),
      insuranceExpiry: json['insurance_expiry']?.toString(),
      inspectionDate: json['inspection_date']?.toString(),
      maintenanceInterval: int.tryParse(json['maintenance_interval']?.toString() ?? '500') ?? 500,
      nextMaintenanceHours: int.tryParse(json['next_maintenance_hours']?.toString() ?? '0') ?? 0,
      maintenanceIntervalKm: int.tryParse(json['maintenance_interval_km']?.toString() ?? '0') ?? 0,
      nextMaintenanceKm: int.tryParse(json['next_maintenance_km']?.toString() ?? '0') ?? 0,
      currentKm: int.tryParse(json['current_km']?.toString() ?? '0') ?? 0,
      currentHours: double.tryParse(json['current_hours']?.toString() ?? '0') ?? 0,
      hourlyRate: double.tryParse(json['hourly_rate']?.toString() ?? '0') ?? 0,
      hasBehaviorMonitor: json['has_behavior_monitor'] == 1 || json['has_behavior_monitor'] == true,
      has360Camera: json['has_360_camera'] == 1 || json['has_360_camera'] == true,
      assetValue: double.tryParse(json['asset_value']?.toString() ?? '0') ?? 0,
      photos: photos,
      vehicleStatus: json['vehicle_status']?.toString(),
      driverName: json['driver_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  /// 活跃保养模式：工时保养间隔>0时启用工时模式，=0时走公里模式（互斥）
  bool get useHoursMaintenance => maintenanceInterval > 0;
  bool get useKmMaintenance => maintenanceIntervalKm > 0;

  /// 工时保养状态
  String get hoursStatus {
    if (nextMaintenanceHours <= 0) return '未设置';
    final remain = nextMaintenanceHours - currentHours;
    if (remain < 0) return '保养过期';
    if (remain <= 50) return '即将保养';
    return '正常';
  }

  /// 公里保养状态
  String get kmStatus {
    if (nextMaintenanceKm <= 0) return '未设置';
    final remain = nextMaintenanceKm - currentKm;
    if (remain < 0) return '保养过期';
    if (remain <= 500) return '即将保养';
    return '正常';
  }
}
