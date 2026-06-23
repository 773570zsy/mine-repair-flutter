import '../models/vehicle.dart';
import '../models/inspection.dart';
import '../models/attendance.dart';
import '../models/part.dart';
import 'http_client.dart';

class InspectionService {
  final HttpClient _client = HttpClient();

  // ==================== 点检 ====================

  /// 获取驾驶员可检车辆
  Future<List<Vehicle>> getMyVehicles() async {
    final resp = await _client.get('/inspection/my-vehicles');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取车辆列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => Vehicle.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 获取驾驶员列表
  Future<List<Map<String, dynamic>>> getDriverList() async {
    final resp = await _client.get('/inspection/driver-list');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取驾驶员列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((d) => d as Map<String, dynamic>).toList();
  }

  /// 获取所有人员列表
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final resp = await _client.get('/inspection/all-users');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取人员列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((u) => u as Map<String, dynamic>).toList();
  }

  /// 早检提交
  Future<void> submitMorningCheck({
    required int vehicleId,
    int? driverId,
    String? oilLevel,
    String? coolantLevel,
    String? appearance,
    String? tireCondition,
    String? toolkitCheck,
    String? overallStatus,
    String? abnormalDesc,
    String? notes,
    double? startHours,
    double? startKm,
    List<String>? photos,
    String? mentalState,
    String? ppeWearing,
    int? bloodPressureHigh,
    int? bloodPressureLow,
  }) async {
    final resp = await _client.post('/inspection/morning-check', data: {
      'vehicle_id': vehicleId,
      if (driverId != null) 'driver_id': driverId,
      'oil_level': oilLevel ?? 'high',
      'coolant_level': coolantLevel ?? 'high',
      'appearance': appearance ?? 'normal',
      'tire_condition': tireCondition ?? 'normal',
      'toolkit_check': toolkitCheck ?? 'ok',
      'overall_status': overallStatus ?? 'normal',
      'abnormal_desc': abnormalDesc ?? '',
      'notes': notes ?? '',
      'start_hours': startHours ?? 0,
      'start_km': startKm ?? 0,
      'photos': photos ?? [],
      'mental_state': mentalState ?? '',
      'ppe_wearing': ppeWearing ?? '',
      'blood_pressure_high': bloodPressureHigh ?? 0,
      'blood_pressure_low': bloodPressureLow ?? 0,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '早检提交失败');
  }

  /// 晚检提交
  Future<void> submitEveningCheck({
    required int vehicleId,
    int? driverId,
    double? endHours,
    double? fuelAmount,
    String? attendanceSymbol,
    String? parkingLocation,
    double? endKm,
    List<String>? photos,
  }) async {
    final resp = await _client.post('/inspection/evening-check', data: {
      'vehicle_id': vehicleId,
      if (driverId != null) 'driver_id': driverId,
      'end_hours': endHours ?? 0,
      'fuel_amount': fuelAmount ?? 0,
      'attendance_symbol': attendanceSymbol ?? '',
      'parking_location': parkingLocation ?? '',
      'end_km': endKm ?? 0,
      'photos': photos ?? [],
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '晚检提交失败');
  }

  /// 我的点检记录
  Future<List<InspectionRecord>> getMyRecords({String? month}) async {
    final resp = await _client.get('/inspection/my-records',
        queryParams: month != null ? {'month': month} : null);
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取记录失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => InspectionRecord.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// 全部点检记录（管理员）
  Future<List<InspectionRecord>> getAllRecords({
    String? date,
    int? vehicleId,
    int? driverId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.get('/inspection/all-records', queryParams: {
      if (date != null) 'date': date,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (driverId != null) 'driver_id': driverId,
      'page': page,
      'pageSize': pageSize,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取记录失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => InspectionRecord.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// 今日概况
  Future<TodaySummary> getTodaySummary() async {
    final resp = await _client.get('/inspection/today-summary');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取今日概况失败');
    return TodaySummary.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 工时统计
  Future<Map<String, dynamic>> getWorkHoursReport(String month, {int? driverId, int? departmentId}) async {
    final resp = await _client.get('/inspection/work-hours-report',
        queryParams: {
          'month': month,
          if (driverId != null) 'driver_id': driverId,
          if (departmentId != null) 'department_id': departmentId,
        });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取工时统计失败');
    return resp.data as Map<String, dynamic>;
  }

  // ==================== 考勤 ====================

  /// 今日考勤
  Future<AttendanceRecord?> getTodayAttendance() async {
    final resp = await _client.get('/inspection/attendance/today');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取考勤失败');
    if (resp.data == null) return null;
    return AttendanceRecord.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 提交考勤
  Future<double> submitAttendance({
    String? attendanceSymbol,
    double? overtimeHours,
    String? overtimeStart,
    String? overtimeEnd,
    String? overtimeLocation,
    String? vehicleType,
    String? plateNumber,
  }) async {
    final resp = await _client.post('/inspection/attendance/submit', data: {
      'attendance_symbol': attendanceSymbol ?? '',
      'overtime_hours': overtimeHours ?? 0,
      'overtime_start': overtimeStart ?? '',
      'overtime_end': overtimeEnd ?? '',
      'overtime_location': overtimeLocation ?? '',
      'vehicle_type': vehicleType ?? '',
      'plate_number': plateNumber ?? '',
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '提交失败');
    final data = resp.data as Map<String, dynamic>?;
    return (data?['overtime_hours'] as num?)?.toDouble() ?? 0;
  }

  /// 考勤报表（管理员）
  Future<List<AttendanceRecord>> getAttendanceReport({
    required String month,
    int? driverId,
    int? departmentId,
  }) async {
    final resp = await _client.get('/inspection/attendance/report', queryParams: {
      'month': month,
      if (driverId != null) 'driver_id': driverId,
      if (departmentId != null) 'department_id': departmentId,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取报表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// 驾驶员本人的考勤历史记录
  Future<List<AttendanceRecord>> getMyAttendanceHistory(String month) async {
    final resp = await _client.get('/inspection/attendance/report', queryParams: {
      'month': month,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取考勤历史失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ==================== 配件管理 ====================

  /// 配件列表
  Future<List<PartItem>> getPartsList() async {
    final resp = await _client.get('/inspection/parts-list');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取配件列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((p) => PartItem.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// 添加配件（管理员）
  Future<String> addPart({
    required String partName,
    String? partCode,
    int? quantity,
    String? unit,
    double? unitPrice,
    String? remark,
  }) async {
    final resp = await _client.post('/inspection/parts/add', data: {
      'part_name': partName,
      'part_code': partCode ?? '',
      'quantity': quantity ?? 0,
      'unit': unit ?? '个',
      'unit_price': unitPrice ?? 0,
      'remark': remark ?? '',
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '添加失败');
    return resp.msg ?? '添加成功';
  }

  /// 搜索配件
  Future<List<PartItem>> searchParts(String keyword) async {
    final resp = await _client.get('/inspection/parts/search',
        queryParams: {'q': keyword});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '搜索失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((p) => PartItem.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// 删除配件（管理员）
  Future<void> deletePart(int partId) async {
    final resp = await _client.delete('/inspection/parts/$partId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '删除失败');
  }

  /// 设置配件库存阈值（管理员）
  Future<String> updateThreshold(int partId, int threshold) async {
    final resp = await _client.put('/inspection/parts/threshold', data: {
      'part_id': partId,
      'threshold': threshold,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '设置失败');
    return resp.msg ?? '阈值已更新';
  }

  /// 提交领用申请（驾驶员）
  Future<String> requisitionPart({
    required int partId,
    int? vehicleId,
    required int quantity,
    String? reason,
  }) async {
    final resp = await _client.post('/inspection/parts/requisition', data: {
      'part_id': partId,
      'vehicle_id': vehicleId,
      'quantity': quantity,
      'reason': reason ?? '',
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '申请失败');
    return resp.msg ?? '申请已提交';
  }

  /// 确认出库（管理员）
  Future<void> confirmRequisition(int reqId) async {
    final resp = await _client.post('/inspection/parts/confirm/$reqId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
  }

  /// 驳回顾用（管理员）
  Future<void> rejectRequisition(int reqId) async {
    final resp = await _client.post('/inspection/parts/reject/$reqId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
  }

  /// 领用记录
  Future<List<PartRequisition>> getRequisitions({
    String? dateFrom,
    String? dateTo,
    int? userId,
  }) async {
    final resp = await _client.get('/inspection/parts/requisitions', queryParams: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (userId != null) 'user_id': userId,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取记录失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => PartRequisition.fromJson(r as Map<String, dynamic>)).toList();
  }
}
