/// 驾驶员考勤记录
class AttendanceRecord {
  final int id;
  final int driverId;
  final String attendanceDate;
  final String? attendanceSymbol;
  final double overtimeHours;
  final String? overtimeStart;
  final String? overtimeEnd;
  final String? overtimeLocation;
  final String? plateNumber;
  final String? vehicleType;
  final String? driverName;
  final String? createdAt;

  AttendanceRecord({
    required this.id,
    required this.driverId,
    required this.attendanceDate,
    this.attendanceSymbol,
    this.overtimeHours = 0,
    this.overtimeStart,
    this.overtimeEnd,
    this.overtimeLocation,
    this.plateNumber,
    this.vehicleType,
    this.driverName,
    this.createdAt,
  });

  /// 考勤符号显示
  String get symbolLabel {
    if (attendanceSymbol == null || attendanceSymbol!.isEmpty) return '未打卡';
    return attendanceSymbol!;
  }

  bool get hasOvertime => overtimeHours > 0;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int? ?? 0,
      driverId: json['driver_id'] as int? ?? 0,
      attendanceDate: (json['attendance_date'] ?? '') as String,
      attendanceSymbol: json['attendance_symbol'] as String?,
      overtimeHours: (json['overtime_hours'] as num?)?.toDouble() ?? 0,
      overtimeStart: json['overtime_start'] as String?,
      overtimeEnd: json['overtime_end'] as String?,
      overtimeLocation: json['overtime_location'] as String?,
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      driverName: json['driver_name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
