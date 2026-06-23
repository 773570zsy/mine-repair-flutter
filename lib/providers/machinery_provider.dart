import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/machinery.dart';
import '../services/machinery_service.dart';
import 'auth_provider.dart';
import 'ticker.dart';

/// Service singleton
final machineryServiceProvider = Provider<MachineryService>((ref) => MachineryService());

// ==================== 申请方 ====================

/// 我的申请列表（30秒自动刷新）
final myMachineryApplicationsProvider = FutureProvider<List<MachineryApplication>>((ref) {
  ref.watch(authProvider); // 账号切换时重新拉取
  ref.watch(listTickerProvider);
  return ref.read(machineryServiceProvider).getMyApplications();
});

/// 当前进行中的申请
final activeMachineryApplicationsProvider = FutureProvider<List<MachineryApplication>>((ref) {
  ref.watch(authProvider);
  return ref.read(machineryServiceProvider).getActiveApplications();
});

/// 费用统计
final machineryCostStatsProvider = FutureProvider<MachineryCostStats>((ref) {
  ref.watch(authProvider);
  return ref.read(machineryServiceProvider).getMyCostStats();
});

// ==================== 调度员 ====================

/// 待指派列表（含资源统计，30秒自动刷新）
final machineryPendingListProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(authProvider); // 账号切换时重新拉取
  ref.watch(listTickerProvider);
  return ref.read(machineryServiceProvider).getPendingList();
});

/// 全部申请列表（筛选参数）
final machineryAllApplicationsProvider = FutureProvider.family<List<MachineryApplication>, Map<String, String?>>((ref, filters) {
  ref.watch(authProvider);
  return ref.read(machineryServiceProvider).getAllApplications(
    status: filters['status'],
    urgency: filters['urgency'],
    keyword: filters['keyword'],
  );
});

/// 已派车列表
final dispatchedListProvider = FutureProvider.family<Map<String, dynamic>, Map<String, String?>>((ref, filters) {
  ref.watch(authProvider);
  return ref.read(machineryServiceProvider).getDispatchedList(
    dateFrom: filters['date_from'],
    dateTo: filters['date_to'],
    period: filters['period'],
  );
});

// ==================== 驾驶员 ====================

/// 驾驶员任务列表
final driverTasksProvider = FutureProvider<List<MachineryApplication>>((ref) {
  ref.watch(authProvider);
  return ref.read(machineryServiceProvider).getDriverTasks();
});

/// 驾驶员历史任务
final driverHistoryProvider = FutureProvider<List<MachineryApplication>>((ref) {
  ref.watch(authProvider);
  return ref.read(machineryServiceProvider).getDriverHistory();
});

// ==================== 操作 ====================

class MachineryActions {
  final MachineryService _service;
  final Ref _ref;

  MachineryActions(this._service, this._ref);

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
    String? feeProvider,
  }) async {
    final msg = await _service.submitApplication(
      applicantDept: applicantDept,
      applicantName: applicantName,
      applicantPhone: applicantPhone,
      vehicleType: vehicleType,
      applicationType: applicationType,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      workLocation: workLocation,
      workAltitude: workAltitude,
      workPurpose: workPurpose,
      isHazardous: isHazardous,
      urgency: urgency,
      briefingMethod: briefingMethod,
      briefingFiles: briefingFiles,
      feeProvider: feeProvider,
    );
    _ref.invalidate(myMachineryApplicationsProvider);
    return msg;
  }

  Future<Map<String, dynamic>> earlyEnd(int id) async {
    final result = await _service.earlyEnd(id);
    _ref.invalidate(myMachineryApplicationsProvider);
    _ref.invalidate(activeMachineryApplicationsProvider);
    return result;
  }

  Future<String> cancelApplication(int id) async {
    final msg = await _service.cancelApplication(id);
    _ref.invalidate(myMachineryApplicationsProvider);
    _ref.invalidate(machineryPendingListProvider);
    return msg;
  }

  Future<String> revokeAssign(int id) async {
    final msg = await _service.revokeAssign(id);
    _ref.invalidate(machineryPendingListProvider);
    _ref.invalidate(machineryAllApplicationsProvider);
    return msg;
  }

  Future<String> assign({
    required int id,
    required int assignedVehicleId,
    required int assignedDriverId,
  }) async {
    final msg = await _service.assign(
      id: id,
      assignedVehicleId: assignedVehicleId,
      assignedDriverId: assignedDriverId,
    );
    _ref.invalidate(machineryPendingListProvider);
    _ref.invalidate(machineryAllApplicationsProvider);
    return msg;
  }
}

final machineryActionsProvider = Provider<MachineryActions>((ref) {
  final service = ref.read(machineryServiceProvider);
  return MachineryActions(service, ref);
});

// ==================== 调度看板 ====================

final dispatchKanbanProvider = FutureProvider<DispatchKanban>((ref) {
  ref.watch(authProvider);
  return ref.read(machineryServiceProvider).getKanban();
});
