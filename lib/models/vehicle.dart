class Vehicle {
  final int id;
  final String plateNumber;
  final String vehicleType;
  final String? model;
  final String? vin;
  final String? engineNumber;
  final String status;
  final int? currentDriverId;
  final String? driverName;
  final String? driverPhone;
  final int? initialEngineHours;
  final int? maintenanceIntervalHours;
  final int? nextMaintenanceHours;
  final double? latestEndHours;
  final double? hourlyRate;
  final double? assetValue;
  final int? departmentId;
  final String? purchaseDate;
  final String? remark;

  Vehicle({
    required this.id,
    required this.plateNumber,
    required this.vehicleType,
    this.model,
    this.vin,
    this.engineNumber,
    this.status = 'normal',
    this.currentDriverId,
    this.driverName,
    this.driverPhone,
    this.initialEngineHours,
    this.maintenanceIntervalHours,
    this.nextMaintenanceHours,
    this.latestEndHours,
    this.hourlyRate,
    this.assetValue,
    this.departmentId,
    this.purchaseDate,
    this.remark,
  });

  String get displayLabel => '$plateNumber${model != null ? ' ($model)' : ''}';

  bool get isNormal => status == 'normal';
  bool get isRepairing => status == 'repairing';

  bool get needsMaintenance {
    if (nextMaintenanceHours == null || latestEndHours == null) return false;
    return latestEndHours! >= nextMaintenanceHours!;
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      plateNumber: (json['plate_number'] ?? '') as String,
      vehicleType: (json['vehicle_type'] ?? '') as String,
      model: json['model'] as String?,
      vin: json['vin'] as String?,
      engineNumber: json['engine_number'] as String?,
      status: (json['status'] ?? 'normal') as String,
      currentDriverId: json['current_driver_id'] as int?,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      initialEngineHours: json['initial_engine_hours'] as int?,
      maintenanceIntervalHours: json['maintenance_interval_hours'] as int?,
      nextMaintenanceHours: json['next_maintenance_hours'] as int?,
      latestEndHours: (json['latest_end_hours'] as num?)?.toDouble(),
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      assetValue: (json['asset_value'] as num?)?.toDouble(),
      departmentId: json['department_id'] as int?,
      purchaseDate: json['purchase_date'] as String?,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plate_number': plateNumber,
    'vehicle_type': vehicleType,
    'model': model,
    'vin': vin,
    'engine_number': engineNumber,
    'status': status,
    'current_driver_id': currentDriverId,
    'driver_name': driverName,
    'driver_phone': driverPhone,
    'initial_engine_hours': initialEngineHours,
    'maintenance_interval_hours': maintenanceIntervalHours,
    'next_maintenance_hours': nextMaintenanceHours,
    'latest_end_hours': latestEndHours,
    'hourly_rate': hourlyRate,
    'asset_value': assetValue,
    'department_id': departmentId,
    'purchase_date': purchaseDate,
    'remark': remark,
  };
}
