import '../models/admin.dart';
import '../models/vehicle.dart';
import 'http_client.dart';

class AdminService {
  final HttpClient _client = HttpClient();

  // ==================== 仪表盘 ====================
  Future<AdminDashboard> getDashboard() async {
    final resp = await _client.get('/admin/dashboard');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取仪表盘失败');
    return AdminDashboard.fromJson(resp.data as Map<String, dynamic>);
  }

  // ==================== 用户管理 ====================
  Future<List<AdminUser>> getUsers({String? role, String? keyword}) async {
    final resp = await _client.get('/admin/users', queryParams: {
      if (role != null) 'role': role,
      if (keyword != null) 'keyword': keyword,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取用户列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => AdminUser.fromJson(v as Map<String, dynamic>)).toList();
  }

  Future<List<Department>> getDepartments() async {
    final resp = await _client.get('/admin/departments');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取部门列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => Department.fromJson(v as Map<String, dynamic>)).toList();
  }

  Future<String> addUser({required String name, String phone='', required String role, int? repairShopId, int? departmentId}) async {
    final resp = await _client.post('/admin/users/add', data: {
      'name': name, 'phone': phone, 'role': role,
      'repair_shop_id': repairShopId, 'department_id': departmentId,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '添加失败');
    return resp.msg ?? '添加成功';
  }

  Future<String> deleteUser(int id) async {
    final resp = await _client.delete('/admin/users/$id');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '删除失败');
    return resp.msg ?? '已删除';
  }

  Future<String> importUsers(List<Map<String, dynamic>> users) async {
    final resp = await _client.post('/admin/users/import', data: {'users': users});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '导入失败');
    return resp.msg ?? '导入完成';
  }

  // ==================== 车辆管理 ====================
  Future<String> updateVehicle(int id, {String? plateNumber, String? vehicleType, String? model, String? department, double? hourlyRate}) async {
    final resp = await _client.put('/admin/vehicles/$id', data: {
      if (plateNumber != null) 'plate_number': plateNumber,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (model != null) 'model': model,
      if (department != null) 'department': department,
      if (hourlyRate != null) 'hourly_rate': hourlyRate,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '更新失败');
    return resp.msg ?? '更新成功';
  }

  Future<String> deleteVehicle(int id) async {
    final resp = await _client.delete('/admin/vehicles/$id');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '删除失败');
    return resp.msg ?? '已删除';
  }

  Future<String> bindDriver({required int driverId, required int vehicleId}) async {
    final resp = await _client.post('/admin/vehicles/bind', data: {
      'driver_id': driverId, 'vehicle_id': vehicleId,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '绑定失败');
    return resp.msg ?? '绑定成功';
  }

  Future<String> unbindDriver(int bindingId) async {
    final resp = await _client.post('/admin/vehicles/unbind', data: {'binding_id': bindingId});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '解绑失败');
    return resp.msg ?? '解绑成功';
  }

  Future<String> importVehicles(List<Map<String, dynamic>> vehicles) async {
    final resp = await _client.post('/admin/vehicles/import', data: {'vehicles': vehicles});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '导入失败');
    return resp.msg ?? '导入完成';
  }

  /// 获取车辆列表（复用 vehicle service 的接口）
  Future<List<Vehicle>> getVehicles() async {
    final resp = await _client.get('/vehicles');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取车辆列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => Vehicle.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 获取驾驶员列表（用于绑定）
  Future<List<AdminUser>> getDriverList() async {
    return getUsers(role: 'driver');
  }

  // ==================== 修理厂管理 ====================
  Future<List<RepairShop>> getRepairShops() async {
    final resp = await _client.get('/admin/repair-shops');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取修理厂列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => RepairShop.fromJson(v as Map<String, dynamic>)).toList();
  }

  Future<String> addRepairShop({required String name, String contactPerson='', String contactPhone='', String remark=''}) async {
    final resp = await _client.post('/admin/repair-shops/add', data: {
      'name': name, 'contact_person': contactPerson, 'contact_phone': contactPhone, 'remark': remark,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '添加失败');
    return resp.msg ?? '添加成功';
  }

  Future<String> deleteRepairShop(int id) async {
    final resp = await _client.delete('/admin/repair-shops/$id');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '删除失败');
    return resp.msg ?? '已删除';
  }

  // ==================== 导出 ====================
  Future<List<ExportOrder>> getExportOrders({String? dateFrom, String? dateTo, int? repairShopId, int? departmentId, String? status, String? plateKeyword, String? vehicleType, String? driverKeyword, String? vehicleDept}) async {
    final resp = await _client.get('/admin/export-orders', queryParams: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (repairShopId != null) 'repair_shop_id': repairShopId.toString(),
      if (departmentId != null) 'department_id': departmentId.toString(),
      if (status != null) 'status': status,
      if (plateKeyword != null && plateKeyword.isNotEmpty) 'plate_keyword': plateKeyword,
      if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle_type': vehicleType,
      if (driverKeyword != null && driverKeyword.isNotEmpty) 'driver_keyword': driverKeyword,
      if (vehicleDept != null && vehicleDept.isNotEmpty) 'vehicle_dept': vehicleDept,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '查询失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => ExportOrder.fromJson(v as Map<String, dynamic>)).toList();
  }

  Future<({List<CostReportItem> items, CostReportSummary summary})> getCostReport({String? dateFrom, String? dateTo, int? repairShopId, int? departmentId, String? deptType, String? plateKeyword, String? driverKeyword, String? vehicleType, String? vehicleDept}) async {
    final resp = await _client.get('/admin/cost-report', queryParams: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (repairShopId != null) 'repair_shop_id': repairShopId.toString(),
      if (departmentId != null) 'department_id': departmentId.toString(),
      if (deptType != null) 'dept_type': deptType,
      if (plateKeyword != null && plateKeyword.isNotEmpty) 'plate_keyword': plateKeyword,
      if (driverKeyword != null && driverKeyword.isNotEmpty) 'driver_keyword': driverKeyword,
      if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle_type': vehicleType,
      if (vehicleDept != null && vehicleDept.isNotEmpty) 'vehicle_dept': vehicleDept,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '查询失败');
    final data = resp.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? []).map((v) => CostReportItem.fromJson(v as Map<String, dynamic>)).toList();
    final summary = CostReportSummary.fromJson(data['summary'] as Map<String, dynamic>? ?? {});
    return (items: items, summary: summary);
  }

  /// 导出XLSX — 返回文件字节（通过浏览器下载）
  Future<void> exportOrdersXlsx({String? dateFrom, String? dateTo, int? repairShopId, int? departmentId, String? status}) async {
    final resp = await _client.post('/admin/export-orders-xlsx', data: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (repairShopId != null) 'repair_shop_id': repairShopId,
      if (departmentId != null) 'department_id': departmentId,
      if (status != null) 'status': status,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '导出失败');
  }

  Future<void> exportCostXlsx({String? dateFrom, String? dateTo, int? repairShopId, String? deptType}) async {
    final resp = await _client.post('/admin/export-cost-xlsx', data: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (repairShopId != null) 'repair_shop_id': repairShopId,
      if (deptType != null) 'dept_type': deptType,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '导出失败');
  }

  // ==================== 系统配置 ====================
  Future<Map<String, String>> getConfig() async {
    final resp = await _client.get('/admin/config');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取配置失败');
    final data = resp.data as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<String> saveConfig(Map<String, String> config) async {
    final resp = await _client.post('/admin/config/save', data: {'config': config});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '保存失败');
    return resp.msg ?? '保存成功';
  }

  // ==================== 月度费用统计 ====================
  Future<List<MonthlyCostStat>> getMonthlyCostStats() async {
    final resp = await _client.get('/admin/monthly-cost-stats');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MonthlyCostStat.fromJson(v as Map<String, dynamic>)).toList();
  }

  // ==================== 备份 ====================
  Future<String> backupDb() async {
    final resp = await _client.post('/admin/backup-db');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '备份失败');
    return resp.msg ?? '备份成功';
  }

  Future<List<DbBackup>> getBackupList() async {
    final resp = await _client.get('/admin/backup-list');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取备份列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => DbBackup.fromJson(v as Map<String, dynamic>)).toList();
  }

  Future<String> restoreBackup(String filename) async {
    final resp = await _client.post('/admin/restore-backup', data: {'filename': filename});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '恢复失败');
    return resp.msg ?? '恢复成功';
  }

  // ==================== 修改密码 ====================
  Future<String> changePassword(String oldPwd, String newPwd) async {
    final resp = await _client.post('/admin/change-password', data: {
      'old_pwd': oldPwd, 'new_pwd': newPwd,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '修改失败');
    return resp.msg ?? '密码修改成功';
  }

  // ==================== 每日一测 ====================
  /// 获取今日题目：返回 {done, questions?, result?}
  /// - done=false → questions 包含 5 道题目
  /// - done=true  → result 包含今日答题结果
  Future<({bool done, List<QuizQuestion>? questions, QuizResult? result})> getTodayQuiz() async {
    final resp = await _client.get('/quiz/today');
    if (!resp.isSuccess) {
      if (resp.code == 404) throw Exception('今日暂无题目');
      throw Exception(resp.msg ?? '获取题目失败');
    }
    final data = resp.data as Map<String, dynamic>;
    final done = data['done'] == true;
    if (done) {
      return (done: true, questions: null, result: QuizResult.fromJson(data['result'] as Map<String, dynamic>));
    } else {
      final qList = (data['questions'] as List<dynamic>?)?.map((v) => QuizQuestion.fromJson(v as Map<String, dynamic>)).toList() ?? [];
      return (done: false, questions: qList, result: null);
    }
  }

  /// 提交答案（一次性提交所有5道题）
  Future<QuizResult> submitQuiz(List<Map<String, dynamic>> answers) async {
    final resp = await _client.post('/quiz/submit', data: {'answers': answers});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '提交失败');
    return QuizResult.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 获取本月排行榜
  Future<List<QuizLeaderboardEntry>> getLeaderboard() async {
    final resp = await _client.get('/quiz/leaderboard');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取排行榜失败');
    final data = resp.data as Map<String, dynamic>;
    final list = data['leaderboard'] as List<dynamic>? ?? [];
    return list.map((v) => QuizLeaderboardEntry.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 点赞/取消点赞（给用户点赞，按月）
  Future<String> likeUser(int targetUserId, String month) async {
    final resp = await _client.post('/quiz/like', data: {'target_user_id': targetUserId, 'month': month});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
    return resp.msg ?? (resp.data?['liked'] == true ? '已点赞' : '已取消点赞');
  }
}
