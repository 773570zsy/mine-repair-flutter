import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin.dart';
import '../services/admin_service.dart';
import 'ticker.dart';

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

// 仪表盘（每15秒自动刷新）
final adminDashboardProvider = FutureProvider<AdminDashboard>((ref) {
  ref.watch(dashboardTickerProvider);
  return ref.read(adminServiceProvider).getDashboard();
});

// 用户列表
final adminUsersProvider = FutureProvider.family<List<AdminUser>, UserFilter>((ref, filter) {
  return ref.read(adminServiceProvider).getUsers(role: filter.role, keyword: filter.keyword);
});

class UserFilter {
  final String? role;
  final String? keyword;
  UserFilter({this.role, this.keyword});
  @override
  bool operator ==(Object o) => o is UserFilter && o.role == role && o.keyword == keyword;
  @override
  int get hashCode => Object.hash(role, keyword);
}

// 驾驶员列表（供筛选下拉使用）
final driverListProvider = FutureProvider<List<AdminUser>>((ref) {
  return ref.read(adminServiceProvider).getUsers(role: 'driver');
});

// 部门列表
final departmentsProvider = FutureProvider<List<Department>>((ref) {
  return ref.read(adminServiceProvider).getDepartments();
});

// 修理厂列表
final repairShopsProvider = FutureProvider<List<RepairShop>>((ref) {
  return ref.read(adminServiceProvider).getRepairShops();
});

// 备份列表
final backupListProvider = FutureProvider<List<DbBackup>>((ref) {
  return ref.read(adminServiceProvider).getBackupList();
});

// 系统配置
final adminConfigProvider = FutureProvider<Map<String, String>>((ref) {
  return ref.read(adminServiceProvider).getConfig();
});

// 月度费用
final monthlyCostStatsProvider = FutureProvider<List<MonthlyCostStat>>((ref) {
  return ref.read(adminServiceProvider).getMonthlyCostStats();
});

// 导出工单
final exportOrdersProvider = FutureProvider.family<List<ExportOrder>, ExportFilter>((ref, f) {
  return ref.read(adminServiceProvider).getExportOrders(dateFrom: f.dateFrom, dateTo: f.dateTo, repairShopId: f.repairShopId, departmentId: f.departmentId, status: f.status, plateKeyword: f.plateKeyword, vehicleType: f.vehicleType, driverKeyword: f.driverKeyword, vehicleDept: f.vehicleDept);
});

class ExportFilter {
  final String? dateFrom, dateTo; final int? repairShopId, departmentId; final String? status; final String? plateKeyword; final String? vehicleType; final String? driverKeyword; final String? vehicleDept;
  ExportFilter({this.dateFrom, this.dateTo, this.repairShopId, this.departmentId, this.status, this.plateKeyword, this.vehicleType, this.driverKeyword, this.vehicleDept});
  @override
  bool operator ==(Object o) => o is ExportFilter && o.dateFrom==dateFrom && o.dateTo==dateTo && o.repairShopId==repairShopId && o.departmentId==departmentId && o.status==status && o.plateKeyword==plateKeyword && o.vehicleType==vehicleType && o.driverKeyword==driverKeyword && o.vehicleDept==vehicleDept;
  @override
  int get hashCode => Object.hash(dateFrom, dateTo, repairShopId, departmentId, status, plateKeyword, vehicleType, driverKeyword, vehicleDept);
}

// 费用报表
final costReportProvider = FutureProvider.family<({List<CostReportItem> items, CostReportSummary summary}), CostFilter>((ref, f) {
  return ref.read(adminServiceProvider).getCostReport(dateFrom: f.dateFrom, dateTo: f.dateTo, repairShopId: f.repairShopId, departmentId: f.departmentId, deptType: f.deptType, plateKeyword: f.plateKeyword, driverKeyword: f.driverKeyword, vehicleType: f.vehicleType, vehicleDept: f.vehicleDept);
});

class CostFilter {
  final String? dateFrom, dateTo; final int? repairShopId; final int? departmentId; final String? deptType; final String? plateKeyword; final String? driverKeyword; final String? vehicleType; final String? vehicleDept;
  CostFilter({this.dateFrom, this.dateTo, this.repairShopId, this.departmentId, this.deptType, this.plateKeyword, this.driverKeyword, this.vehicleType, this.vehicleDept});
  @override
  bool operator ==(Object o) => o is CostFilter && o.dateFrom==dateFrom && o.dateTo==dateTo && o.repairShopId==repairShopId && o.departmentId==departmentId && o.deptType==deptType && o.plateKeyword==plateKeyword && o.driverKeyword==driverKeyword && o.vehicleType==vehicleType && o.vehicleDept==vehicleDept;
  @override
  int get hashCode => Object.hash(dateFrom, dateTo, repairShopId, departmentId, deptType, plateKeyword, driverKeyword, vehicleType, vehicleDept);
}

// 每日一测
typedef TodayQuizData = ({bool done, List<QuizQuestion>? questions, QuizResult? result});

final todayQuizProvider = FutureProvider<TodayQuizData>((ref) {
  return ref.read(adminServiceProvider).getTodayQuiz();
});

final quizLeaderboardProvider = FutureProvider<List<QuizLeaderboardEntry>>((ref) {
  return ref.read(adminServiceProvider).getLeaderboard();
});

// 操作
class AdminActions {
  final AdminService _s;
  AdminActions(this._s);

  // 用户
  Future<String> addUser({required String name, String phone='', required String role, int? repairShopId, int? departmentId}) =>
    _s.addUser(name: name, phone: phone, role: role, repairShopId: repairShopId, departmentId: departmentId);
  Future<String> deleteUser(int id) => _s.deleteUser(id);
  Future<String> importUsers(List<Map<String, dynamic>> users) => _s.importUsers(users);

  // 车辆
  Future<String> updateVehicle(int id, {String? plateNumber, String? vehicleType, String? model, String? department, double? hourlyRate}) =>
    _s.updateVehicle(id, plateNumber: plateNumber, vehicleType: vehicleType, model: model, department: department, hourlyRate: hourlyRate);
  Future<String> deleteVehicle(int id) => _s.deleteVehicle(id);
  Future<String> bindDriver({required int driverId, required int vehicleId}) => _s.bindDriver(driverId: driverId, vehicleId: vehicleId);
  Future<String> unbindDriver(int bid) => _s.unbindDriver(bid);
  Future<String> importVehicles(List<Map<String, dynamic>> vehicles) => _s.importVehicles(vehicles);

  // 修理厂
  Future<String> addRepairShop({required String name, String cp='', String cph='', String r=''}) =>
    _s.addRepairShop(name: name, contactPerson: cp, contactPhone: cph, remark: r);
  Future<String> deleteRepairShop(int id) => _s.deleteRepairShop(id);

  // 配置
  Future<String> saveConfig(Map<String, String> c) => _s.saveConfig(c);

  // 备份
  Future<String> backupDb() => _s.backupDb();
  Future<String> restoreBackup(String fn) => _s.restoreBackup(fn);

  // 密码
  Future<String> changePassword(String o, String n) => _s.changePassword(o, n);

  // 答题
  Future<QuizResult> submitQuiz(List<Map<String, dynamic>> answers) => _s.submitQuiz(answers);
  Future<String> likeUser(int targetUserId, String month) => _s.likeUser(targetUserId, month);

  // 导出
  Future<void> exportOrdersXlsx({String? df, String? dt, int? rs, int? dept, String? st}) =>
    _s.exportOrdersXlsx(dateFrom: df, dateTo: dt, repairShopId: rs, departmentId: dept, status: st);
  Future<void> exportCostXlsx({String? df, String? dt, int? rs, String? dpt}) =>
    _s.exportCostXlsx(dateFrom: df, dateTo: dt, repairShopId: rs, deptType: dpt);
}

final adminActionsProvider = Provider<AdminActions>((ref) {
  return AdminActions(ref.read(adminServiceProvider));
});
