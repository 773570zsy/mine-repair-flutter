import '../models/machinery.dart';
import '../models/vehicle.dart';
import 'http_client.dart';

class MachineryService {
  final HttpClient _client = HttpClient();

  // ==================== 申请方 ====================

  /// 提交申请
  Future<String> submitApplication({
    required String applicantDept,
    required String applicantName,
    required String applicantPhone,
    String? vehicleType,
    String? applicationType,
    required String scheduledStart,
    required String scheduledEnd,
    required String workLocation,
    String? workAltitude,
    required String workPurpose,
    bool isHazardous = false,
    String? urgency,
    String? briefingMethod,
    List<String>? briefingFiles,
  }) async {
    final resp = await _client.post('/machinery/apply', data: {
      'applicant_dept': applicantDept,
      'applicant_name': applicantName,
      'applicant_phone': applicantPhone,
      'vehicle_type': vehicleType ?? '',
      'application_type': applicationType ?? 'short_term',
      'scheduled_start': scheduledStart,
      'scheduled_end': scheduledEnd,
      'work_location': workLocation,
      'work_altitude': workAltitude ?? '',
      'work_purpose': workPurpose,
      'is_hazardous': isHazardous,
      'urgency': urgency ?? 'normal',
      'briefing_method': briefingMethod ?? '',
      'briefing_files': briefingFiles ?? [],
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '提交失败');
    return resp.msg ?? '申请已提交';
  }

  /// 我的申请列表
  Future<List<MachineryApplication>> getMyApplications() async {
    final resp = await _client.get('/machinery/my-applications');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取申请列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MachineryApplication.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 当前进行中的申请
  Future<List<MachineryApplication>> getActiveApplications() async {
    final resp = await _client.get('/machinery/active');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MachineryApplication.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 提前结束用车
  Future<Map<String, dynamic>> earlyEnd(int id) async {
    final resp = await _client.post('/machinery/early-end/$id');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
    return resp.data as Map<String, dynamic>? ?? {};
  }

  /// 取消申请
  Future<String> cancelApplication(int id) async {
    final resp = await _client.post('/machinery/cancel/$id');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '取消失败');
    return resp.msg ?? '已取消';
  }

  /// 费用统计
  Future<MachineryCostStats> getMyCostStats() async {
    final resp = await _client.get('/machinery/my-cost-stats');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取费用统计失败');
    return MachineryCostStats.fromJson(resp.data as Map<String, dynamic>);
  }

  // ==================== 调度员 ====================

  /// 待指派列表
  Future<Map<String, dynamic>> getPendingList() async {
    final resp = await _client.get('/machinery/pending-list');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取失败');
    return resp.data as Map<String, dynamic>;
  }

  /// 全部申请列表
  Future<List<MachineryApplication>> getAllApplications({
    String? status,
    String? urgency,
    String? keyword,
  }) async {
    final resp = await _client.get('/machinery/list-all', queryParams: {
      if (status != null) 'status': status,
      if (urgency != null) 'urgency': urgency,
      if (keyword != null) 'keyword': keyword,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MachineryApplication.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 指派车辆和驾驶员
  Future<String> assign({
    required int id,
    required int assignedVehicleId,
    required int assignedDriverId,
  }) async {
    final resp = await _client.post('/machinery/assign/$id', data: {
      'assigned_vehicle_id': assignedVehicleId,
      'assigned_driver_id': assignedDriverId,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '指派失败');
    return resp.msg ?? '派车成功';
  }

  /// 撤销指派
  Future<String> revokeAssign(int id) async {
    final resp = await _client.post('/machinery/revoke/$id');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '撤销指派失败');
    return resp.msg ?? '指派已撤销';
  }

  /// 已派车列表
  Future<Map<String, dynamic>> getDispatchedList({
    String? dateFrom,
    String? dateTo,
    String? period,
  }) async {
    final resp = await _client.get('/machinery/dispatched-list', queryParams: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (period != null) 'period': period,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取失败');
    return resp.data as Map<String, dynamic>;
  }

  // ==================== 驾驶员 ====================

  /// 收到的派车任务
  Future<List<MachineryApplication>> getDriverTasks() async {
    final resp = await _client.get('/machinery/driver-tasks');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取任务失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MachineryApplication.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 历史任务
  Future<List<MachineryApplication>> getDriverHistory() async {
    final resp = await _client.get('/machinery/driver-history');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取历史失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MachineryApplication.fromJson(v as Map<String, dynamic>)).toList();
  }

  // ==================== 通用 ====================

  /// 申请详情
  Future<MachineryApplication> getDetail(int id) async {
    final resp = await _client.get('/machinery/detail/$id');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取详情失败');
    return MachineryApplication.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 获取可用车辆列表（用于指派）
  Future<List<Vehicle>> getAvailableVehicles() async {
    final resp = await _client.get('/vehicles');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取车辆列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => Vehicle.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 获取驾驶员列表（用于指派）
  Future<List<Map<String, dynamic>>> getDriverList() async {
    final resp = await _client.get('/inspection/driver-list');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取驾驶员列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((d) => d as Map<String, dynamic>).toList();
  }

  /// 获取繁忙资源（已指派车辆+驾驶员及其订单信息）
  Future<Map<String, dynamic>> getBusyResources() async {
    final resp = await _client.get('/machinery/busy-resources');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取繁忙资源失败');
    return resp.data as Map<String, dynamic>? ?? {};
  }

  /// 调度看板数据（今日全貌）
  Future<DispatchKanban> getKanban() async {
    final resp = await _client.get('/machinery/kanban');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取看板数据失败');
    return DispatchKanban.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 生成今日已指派文本（企业微信）
  Future<Map<String, dynamic>> generateDailyReport() async {
    final resp = await _client.get('/machinery/generate-daily-report');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '生成失败');
    return resp.data as Map<String, dynamic>? ?? {};
  }
}
