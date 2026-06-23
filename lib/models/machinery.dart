/// 工程机械用车申请
class MachineryApplication {
  final int id;
  final String applicationNo;
  final int applicantId;
  final String applicantDept;
  final String applicantName;
  final String applicantPhone;
  final String vehicleType;
  final String applicationType; // short_term / long_term
  final String scheduledStart;
  final String scheduledEnd;
  final String workLocation;
  final String? workAltitude;
  final String workPurpose;
  final bool isHazardous;
  final String urgency; // normal / urgent / emergency
  final String? briefingMethod;
  final String? briefingFiles;
  final String? feeProvider;
  final String status; // pending / assigned / in_progress / completed / early_completed / cancelled
  final int? assignedVehicleId;
  final int? assignedDriverId;
  final int? dispatcherId;
  final double? hourlyRate;
  final String? actualEndTime;
  final String? settlementEndTime;
  final double? workingHours;
  final double? totalCost;

  // JOIN fields
  final String? assignedPlate;
  final String? assignedVehicleType;
  final String? assignedVehicleModel;
  final String? driverName;
  final String? driverPhone;
  final String? dispatcherName;
  final String? applicantUserName;

  final String? createdAt;
  final String? updatedAt;

  MachineryApplication({
    required this.id,
    required this.applicationNo,
    required this.applicantId,
    required this.applicantDept,
    required this.applicantName,
    required this.applicantPhone,
    required this.vehicleType,
    this.applicationType = 'short_term',
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.workLocation,
    this.workAltitude,
    required this.workPurpose,
    this.isHazardous = false,
    this.urgency = 'normal',
    this.briefingMethod,
    this.briefingFiles,
    this.feeProvider,
    this.status = 'pending',
    this.assignedVehicleId,
    this.assignedDriverId,
    this.dispatcherId,
    this.hourlyRate,
    this.actualEndTime,
    this.settlementEndTime,
    this.workingHours,
    this.totalCost,
    this.assignedPlate,
    this.assignedVehicleType,
    this.assignedVehicleModel,
    this.driverName,
    this.driverPhone,
    this.dispatcherName,
    this.applicantUserName,
    this.createdAt,
    this.updatedAt,
  });

  // === computed ===

  /// 当前时间是否在预约时段内
  bool get isWithinScheduledPeriod {
    if (scheduledStart.isEmpty || scheduledEnd.isEmpty) return false;
    final now = DateTime.now();
    final nowStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return nowStr.compareTo(scheduledStart) >= 0 && nowStr.compareTo(scheduledEnd) <= 0;
  }

  String get statusLabel {
    // assigned 状态下，若当前时间在预约时段内则显示"用车中"
    if (status == 'assigned' && isWithinScheduledPeriod) return '用车中';
    const map = {
      'pending': '待指派',
      'assigned': '已指派',
      'in_progress': '用车中',
      'completed': '已完成',
      'early_completed': '提前结束',
      'cancelled': '已取消',
    };
    return map[status] ?? status;
  }

  String get urgencyLabel {
    const map = {
      'normal': '普通',
      'urgent': '加急',
      'emergency': '紧急',
    };
    return map[urgency] ?? urgency;
  }

  String get typeLabel {
    const map = {
      'short_term': '短期',
      'long_term': '长期',
    };
    return map[applicationType] ?? applicationType;
  }

  String get feeProviderLabel {
    if (feeProvider == 'party_a') return '甲方';
    if (feeProvider == 'party_b') return '乙方';
    return '-';
  }

  bool get isPending => status == 'pending';
  bool get isActive => status == 'assigned' || status == 'in_progress';
  bool get isCompleted => status == 'completed' || status == 'early_completed';
  bool get isCancelled => status == 'cancelled';

  String get vehicleDisplay {
    if (assignedPlate == null || assignedPlate!.isEmpty) return '未指派';
    final parts = [assignedPlate!, assignedVehicleType, assignedVehicleModel]
        .where((e) => e != null && e.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  String get workTimeDisplay {
    if (scheduledStart.isEmpty && scheduledEnd.isEmpty) return '-';
    return '$scheduledStart ~ $scheduledEnd';
  }

  factory MachineryApplication.fromJson(Map<String, dynamic> json) {
    return MachineryApplication(
      id: json['id'] ?? 0,
      applicationNo: json['application_no']?.toString() ?? '',
      applicantId: json['applicant_id'] ?? 0,
      applicantDept: json['applicant_dept']?.toString() ?? '',
      applicantName: json['applicant_name']?.toString() ?? '',
      applicantPhone: json['applicant_phone']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? '',
      applicationType: json['application_type']?.toString() ?? 'short_term',
      scheduledStart: json['scheduled_start']?.toString() ?? '',
      scheduledEnd: json['scheduled_end']?.toString() ?? '',
      workLocation: json['work_location']?.toString() ?? '',
      workAltitude: json['work_altitude']?.toString(),
      workPurpose: json['work_purpose']?.toString() ?? '',
      isHazardous: json['is_hazardous'] == 1 || json['is_hazardous'] == true,
      urgency: json['urgency']?.toString() ?? 'normal',
      briefingMethod: json['briefing_method']?.toString(),
      briefingFiles: json['briefing_files']?.toString(),
      feeProvider: json['fee_provider']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      assignedVehicleId: json['assigned_vehicle_id'] as int?,
      assignedDriverId: json['assigned_driver_id'] as int?,
      dispatcherId: json['dispatcher_id'] as int?,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      actualEndTime: json['actual_end_time']?.toString(),
      settlementEndTime: json['settlement_end_time']?.toString(),
      workingHours: (json['working_hours'] as num?)?.toDouble(),
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      assignedPlate: json['assigned_plate']?.toString(),
      assignedVehicleType: json['assigned_vehicle_type']?.toString(),
      assignedVehicleModel: json['assigned_vehicle_model']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      dispatcherName: json['dispatcher_name']?.toString(),
      applicantUserName: json['applicant_user_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

/// 派车资源统计
class MachineryStats {
  final int totalVehicles;
  final int availableVehicles;
  final int totalDrivers;
  final int availableDrivers;

  MachineryStats({
    required this.totalVehicles,
    required this.availableVehicles,
    required this.totalDrivers,
    required this.availableDrivers,
  });

  factory MachineryStats.fromJson(Map<String, dynamic> json) {
    return MachineryStats(
      totalVehicles: json['totalVehicles'] ?? 0,
      availableVehicles: json['availableVehicles'] ?? 0,
      totalDrivers: json['totalDrivers'] ?? 0,
      availableDrivers: json['availableDrivers'] ?? 0,
    );
  }
}

/// 费用统计
class MachineryCostStats {
  final MachineryCostMonth thisMonth;
  final MachineryCostAll allTime;
  final List<MachineryCostItem> recentItems;

  MachineryCostStats({
    required this.thisMonth,
    required this.allTime,
    required this.recentItems,
  });

  factory MachineryCostStats.fromJson(Map<String, dynamic> json) {
    return MachineryCostStats(
      thisMonth: MachineryCostMonth.fromJson(json['thisMonth'] as Map<String, dynamic>? ?? {}),
      allTime: MachineryCostAll.fromJson(json['allTime'] as Map<String, dynamic>? ?? {}),
      recentItems: (json['recentItems'] as List<dynamic>? ?? [])
          .map((e) => MachineryCostItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MachineryCostMonth {
  final int totalCount;
  final int completedCount;
  final int activeCount;
  final double totalCost;
  final double totalHours;

  MachineryCostMonth({
    this.totalCount = 0,
    this.completedCount = 0,
    this.activeCount = 0,
    this.totalCost = 0,
    this.totalHours = 0,
  });

  factory MachineryCostMonth.fromJson(Map<String, dynamic> json) {
    return MachineryCostMonth(
      totalCount: json['totalCount'] ?? 0,
      completedCount: json['completedCount'] ?? 0,
      activeCount: json['activeCount'] ?? 0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MachineryCostAll {
  final double totalCost;
  final int totalCount;

  MachineryCostAll({this.totalCost = 0, this.totalCount = 0});

  factory MachineryCostAll.fromJson(Map<String, dynamic> json) {
    return MachineryCostAll(
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
      totalCount: json['totalCount'] ?? 0,
    );
  }
}

class MachineryCostItem {
  final String applicationNo;
  final String applicantDept;
  final String scheduledStart;
  final String scheduledEnd;
  final double workingHours;
  final double hourlyRate;
  final double totalCost;
  final String status;
  final String applicationType;
  final String? createdAt;

  MachineryCostItem({
    required this.applicationNo,
    required this.applicantDept,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.workingHours = 0,
    this.hourlyRate = 0,
    this.totalCost = 0,
    required this.status,
    this.applicationType = 'short_term',
    this.createdAt,
  });

  factory MachineryCostItem.fromJson(Map<String, dynamic> json) {
    return MachineryCostItem(
      applicationNo: json['application_no']?.toString() ?? '',
      applicantDept: json['applicant_dept']?.toString() ?? '',
      scheduledStart: json['scheduled_start']?.toString() ?? '',
      scheduledEnd: json['scheduled_end']?.toString() ?? '',
      workingHours: (json['working_hours'] as num?)?.toDouble() ?? 0,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      applicationType: json['application_type']?.toString() ?? 'short_term',
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// 已派车列表统计
class DispatchedStats {
  final int totalCount;
  final double totalRevenue;
  final double totalHours;

  DispatchedStats({this.totalCount = 0, this.totalRevenue = 0, this.totalHours = 0});

  factory DispatchedStats.fromJson(Map<String, dynamic> json) {
    return DispatchedStats(
      totalCount: json['totalCount'] ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ==================== 调度看板 ====================

class KanbanTask {
  final int applicationId;
  final String applicationNo;
  final String applicantName;
  final String applicantDept;
  final String workLocation;
  final String workPurpose;
  final String scheduledStart;
  final String scheduledEnd;
  final String? driverName;
  final String? driverPhone;
  final String? plateNumber;

  KanbanTask({
    required this.applicationId,
    this.applicationNo = '',
    this.applicantName = '',
    this.applicantDept = '',
    this.workLocation = '',
    this.workPurpose = '',
    this.scheduledStart = '',
    this.scheduledEnd = '',
    this.driverName,
    this.driverPhone,
    this.plateNumber,
  });

  factory KanbanTask.fromJson(Map<String, dynamic> json) {
    return KanbanTask(
      applicationId: json['application_id'] ?? 0,
      applicationNo: json['application_no'] ?? '',
      applicantName: json['applicant_name'] ?? '',
      applicantDept: json['applicant_dept'] ?? '',
      workLocation: json['work_location'] ?? '',
      workPurpose: json['work_purpose'] ?? '',
      scheduledStart: json['scheduled_start'] ?? '',
      scheduledEnd: json['scheduled_end'] ?? '',
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      plateNumber: json['plate_number']?.toString(),
    );
  }

  String get timeDisplay => '$scheduledStart - $scheduledEnd';
}

class KanbanVehicle {
  final int id;
  final String plateNumber;
  final String vehicleType;
  final String model;
  final String status; // 'normal' | 'repairing' | 'scrapped'
  final String currentStatus; // 'available' | 'busy' | 'repairing'
  final KanbanTask? currentTask;

  KanbanVehicle({
    required this.id,
    this.plateNumber = '',
    this.vehicleType = '',
    this.model = '',
    this.status = 'normal',
    this.currentStatus = 'available',
    this.currentTask,
  });

  factory KanbanVehicle.fromJson(Map<String, dynamic> json) {
    return KanbanVehicle(
      id: json['id'] ?? 0,
      plateNumber: json['plate_number'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      model: json['model'] ?? '',
      status: json['status'] ?? '',
      currentStatus: json['current_status'] ?? 'available',
      currentTask: json['current_task'] != null
          ? KanbanTask.fromJson(json['current_task'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displayName => '$plateNumber ($vehicleType)';
  bool get isBusy => currentStatus == 'busy';
  bool get isAvailable => currentStatus == 'available';
  bool get isRepairing => currentStatus == 'repairing';
}

class KanbanDriver {
  final int id;
  final String name;
  final String phone;
  final String status; // 'active' | 'inactive'
  final String currentStatus; // 'available' | 'busy' | 'on_leave' | 'absent'
  final String? attendanceSymbol;
  final KanbanTask? currentTask;

  KanbanDriver({
    required this.id,
    this.name = '',
    this.phone = '',
    this.status = 'active',
    this.currentStatus = 'available',
    this.attendanceSymbol,
    this.currentTask,
  });

  factory KanbanDriver.fromJson(Map<String, dynamic> json) {
    return KanbanDriver(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? 'active',
      currentStatus: json['current_status'] ?? 'available',
      attendanceSymbol: json['attendance_symbol']?.toString(),
      currentTask: json['current_task'] != null
          ? KanbanTask.fromJson(json['current_task'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isBusy => currentStatus == 'busy';
  bool get isAvailable => currentStatus == 'available';
  bool get isOnLeave => currentStatus == 'on_leave';
  bool get isAbsent => currentStatus == 'absent';

  String get statusLabel {
    switch (currentStatus) {
      case 'busy': return '忙碌';
      case 'on_leave': return attendanceSymbol ?? '请假';
      case 'absent': return '未签到';
      default: return '空闲';
    }
  }
}

class KanbanSummary {
  final int totalVehicles;
  final int availableVehicles;
  final int busyVehicles;
  final int repairingVehicles;
  final int totalDrivers;
  final int availableDrivers;
  final int busyDrivers;
  final int onLeaveDrivers;
  final int absentDrivers;
  final int pendingCount;

  KanbanSummary({
    this.totalVehicles = 0, this.availableVehicles = 0, this.busyVehicles = 0,
    this.repairingVehicles = 0, this.totalDrivers = 0, this.availableDrivers = 0,
    this.busyDrivers = 0, this.onLeaveDrivers = 0, this.absentDrivers = 0,
    this.pendingCount = 0,
  });

  factory KanbanSummary.fromJson(Map<String, dynamic> json) {
    return KanbanSummary(
      totalVehicles: json['totalVehicles'] ?? 0,
      availableVehicles: json['availableVehicles'] ?? 0,
      busyVehicles: json['busyVehicles'] ?? 0,
      repairingVehicles: json['repairingVehicles'] ?? 0,
      totalDrivers: json['totalDrivers'] ?? 0,
      availableDrivers: json['availableDrivers'] ?? 0,
      busyDrivers: json['busyDrivers'] ?? 0,
      onLeaveDrivers: json['onLeaveDrivers'] ?? 0,
      absentDrivers: json['absentDrivers'] ?? 0,
      pendingCount: json['pendingCount'] ?? 0,
    );
  }

  int get activeDrivers => totalDrivers - onLeaveDrivers;  // 未签到也算空闲，不再扣减
}

class DispatchKanban {
  final String date;
  final KanbanSummary summary;
  final List<KanbanVehicle> vehicles;
  final List<KanbanDriver> drivers;
  final List<MachineryApplication> pendingApplications;

  DispatchKanban({
    required this.date,
    required this.summary,
    this.vehicles = const [],
    this.drivers = const [],
    this.pendingApplications = const [],
  });

  factory DispatchKanban.fromJson(Map<String, dynamic> json) {
    return DispatchKanban(
      date: json['date'] ?? '',
      summary: KanbanSummary.fromJson((json['summary'] as Map<String, dynamic>?) ?? {}),
      vehicles: ((json['vehicles'] as List<dynamic>?) ?? [])
          .map((v) => KanbanVehicle.fromJson(v as Map<String, dynamic>))
          .toList(),
      drivers: ((json['drivers'] as List<dynamic>?) ?? [])
          .map((d) => KanbanDriver.fromJson(d as Map<String, dynamic>))
          .toList(),
      pendingApplications: ((json['pendingApplications'] as List<dynamic>?) ?? [])
          .map((a) => MachineryApplication.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}
