/// 保养状态（列表用）
class MaintenanceStatus {
  final int vehicleId;
  final String plateNumber;
  final String vehicleType;
  final String? model;
  final double nextMaintenanceHours;
  final double maintenanceIntervalHours;
  final double currentHours;
  final int currentKm;
  final double remainingHours;
  final String? lastMaintenanceDate;
  final double? lastMaintenanceHours;
  final String status; // normal | soon | overdue | none

  MaintenanceStatus({
    required this.vehicleId,
    required this.plateNumber,
    required this.vehicleType,
    this.model,
    this.nextMaintenanceHours = 0,
    this.maintenanceIntervalHours = 0,
    this.currentHours = 0,
    this.currentKm = 0,
    this.remainingHours = 0,
    this.lastMaintenanceDate,
    this.lastMaintenanceHours,
    this.status = 'normal',
  });

  factory MaintenanceStatus.fromJson(Map<String, dynamic> json) {
    return MaintenanceStatus(
      vehicleId: (json['vehicle_id'] ?? 0) as int,
      plateNumber: (json['plate_number'] ?? '') as String,
      vehicleType: (json['vehicle_type'] ?? '') as String,
      model: json['model'] as String?,
      nextMaintenanceHours: (json['next_maintenance_hours'] ?? 0).toDouble(),
      maintenanceIntervalHours: (json['maintenance_interval_hours'] ?? 0).toDouble(),
      currentHours: (json['current_hours'] ?? 0).toDouble(),
      currentKm: (json['current_km'] ?? 0) as int,
      remainingHours: (json['remaining_hours'] ?? 0).toDouble(),
      lastMaintenanceDate: json['last_maintenance_date'] as String?,
      lastMaintenanceHours: (json['last_maintenance_hours'] as num?)?.toDouble(),
      status: (json['status'] ?? 'normal') as String,
    );
  }

  String get vehicleDisplay =>
      '$plateNumber ($vehicleType)';

  String get statusLabel {
    switch (status) {
      case 'overdue': return '已过期';
      case 'soon': return '即将到期';
      case 'normal': return '正常';
      default: return '未设置';
    }
  }

  String get remainingDisplay {
    if (status == 'none') return '未设置保养';
    if (status == 'overdue') return '已超 ${remainingHours.abs().toStringAsFixed(0)}h';
    return '剩余 ${remainingHours.toStringAsFixed(0)}h';
  }

  bool get isAlert => status == 'overdue' || status == 'soon';
}

/// 保养记录
class MaintenanceRecord {
  final int id;
  final int vehicleId;
  final String maintenanceDate;
  final double currentHours;
  final int currentKm;
  final String maintenanceType;
  final String description;
  final double cost;
  final String partsInfo;
  final String operatorName;
  final String remark;
  final String createdAt;

  MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.maintenanceDate,
    this.currentHours = 0,
    this.currentKm = 0,
    this.maintenanceType = 'regular',
    this.description = '',
    this.cost = 0,
    this.partsInfo = '[]',
    this.operatorName = '',
    this.remark = '',
    this.createdAt = '',
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: (json['id'] ?? 0) as int,
      vehicleId: (json['vehicle_id'] ?? 0) as int,
      maintenanceDate: (json['maintenance_date'] ?? '') as String,
      currentHours: (json['current_hours'] ?? 0).toDouble(),
      currentKm: (json['current_km'] ?? 0) as int,
      maintenanceType: (json['maintenance_type'] ?? 'regular') as String,
      description: (json['description'] ?? '') as String,
      cost: (json['cost'] ?? 0).toDouble(),
      partsInfo: (json['parts_info'] ?? '[]') as String,
      operatorName: (json['operator_name'] ?? '') as String,
      remark: (json['remark'] ?? '') as String,
      createdAt: (json['created_at'] ?? '') as String,
    );
  }

  String get typeLabel {
    switch (maintenanceType) {
      case 'regular': return '常规保养';
      case 'repair': return '维修';
      default: return maintenanceType;
    }
  }
}
