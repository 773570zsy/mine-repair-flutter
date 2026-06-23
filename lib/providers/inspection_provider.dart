import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/inspection.dart';
import '../models/attendance.dart';
import '../models/part.dart';
import '../services/inspection_service.dart';

final inspectionServiceProvider = Provider<InspectionService>((ref) => InspectionService());

// ==================== 点检 ====================

/// 我的车辆
final myVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  return ref.read(inspectionServiceProvider).getMyVehicles();
});

/// 我的点检记录
final myRecordsProvider = FutureProvider.family<List<InspectionRecord>, String?>((ref, month) async {
  return ref.read(inspectionServiceProvider).getMyRecords(month: month);
});

/// 全部点检记录（管理员）
final allRecordsProvider = FutureProvider.family<List<InspectionRecord>, AllRecordsParams>((ref, params) async {
  return ref.read(inspectionServiceProvider).getAllRecords(
    date: params.date,
    vehicleId: params.vehicleId,
    driverId: params.driverId,
    page: params.page,
  );
});

/// 今日概况
final todaySummaryProvider = FutureProvider<TodaySummary>((ref) async {
  return ref.read(inspectionServiceProvider).getTodaySummary();
});

/// 工时统计
final workHoursProvider = FutureProvider.family<Map<String, dynamic>, WorkHoursParams>((ref, params) async {
  return ref.read(inspectionServiceProvider).getWorkHoursReport(params.month, driverId: params.driverId, departmentId: params.departmentId);
});

// ==================== 考勤 ====================

/// 今日考勤
final todayAttendanceProvider = FutureProvider<AttendanceRecord?>((ref) async {
  return ref.read(inspectionServiceProvider).getTodayAttendance();
});

/// 考勤报表
final attendanceReportProvider = FutureProvider.family<List<AttendanceRecord>, AttendanceReportParams>((ref, params) async {
  return ref.read(inspectionServiceProvider).getAttendanceReport(
    month: params.month,
    driverId: params.driverId,
    departmentId: params.departmentId,
  );
});

/// 驾驶员本人的考勤历史记录
final myAttendanceHistoryProvider = FutureProvider.family<List<AttendanceRecord>, String>((ref, month) async {
  return ref.read(inspectionServiceProvider).getMyAttendanceHistory(month);
});

// ==================== 配件 ====================

/// 配件列表
final partsListProvider = FutureProvider<List<PartItem>>((ref) async {
  return ref.read(inspectionServiceProvider).getPartsList();
});

/// 配件搜索
final partsSearchProvider = FutureProvider.family<List<PartItem>, String>((ref, keyword) async {
  return ref.read(inspectionServiceProvider).searchParts(keyword);
});

/// 领用记录
final partRequisitionsProvider = FutureProvider.family<List<PartRequisition>, RequisitionParams?>((ref, params) async {
  return ref.read(inspectionServiceProvider).getRequisitions(
    dateFrom: params?.dateFrom,
    dateTo: params?.dateTo,
    userId: params?.userId,
  );
});

// ==================== 操作 Notifier ====================

class InspectionActions extends StateNotifier<AsyncValue<String?>> {
  final InspectionService _service = InspectionService();

  InspectionActions() : super(const AsyncValue.data(null));

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
    state = const AsyncValue.loading();
    try {
      await _service.submitMorningCheck(
        vehicleId: vehicleId, driverId: driverId,
        oilLevel: oilLevel, coolantLevel: coolantLevel,
        appearance: appearance, tireCondition: tireCondition,
        toolkitCheck: toolkitCheck, overallStatus: overallStatus,
        abnormalDesc: abnormalDesc, notes: notes,
        startHours: startHours, startKm: startKm, photos: photos,
        mentalState: mentalState, ppeWearing: ppeWearing,
        bloodPressureHigh: bloodPressureHigh, bloodPressureLow: bloodPressureLow,
      );
      state = const AsyncValue.data('早检提交成功');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

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
    state = const AsyncValue.loading();
    try {
      await _service.submitEveningCheck(
        vehicleId: vehicleId, driverId: driverId,
        endHours: endHours,
        fuelAmount: fuelAmount, attendanceSymbol: attendanceSymbol,
        parkingLocation: parkingLocation,
        endKm: endKm, photos: photos,
      );
      state = const AsyncValue.data('晚检提交成功');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<double> submitAttendance({
    String? attendanceSymbol,
    double? overtimeHours,
    String? overtimeStart,
    String? overtimeEnd,
    String? overtimeLocation,
    String? vehicleType,
    String? plateNumber,
  }) async {
    state = const AsyncValue.loading();
    try {
      final hours = await _service.submitAttendance(
        attendanceSymbol: attendanceSymbol,
        overtimeHours: overtimeHours,
        overtimeStart: overtimeStart,
        overtimeEnd: overtimeEnd,
        overtimeLocation: overtimeLocation,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
      );
      state = const AsyncValue.data('考勤提交成功');
      return hours;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> addPart({
    required String partName,
    String? partCode,
    int? quantity,
    String? unit,
    double? unitPrice,
    String? remark,
  }) async {
    state = const AsyncValue.loading();
    try {
      final msg = await _service.addPart(
        partName: partName, partCode: partCode,
        quantity: quantity, unit: unit,
        unitPrice: unitPrice, remark: remark,
      );
      state = AsyncValue.data(msg);
      return msg;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> requisitionPart({
    required int partId,
    int? vehicleId,
    required int quantity,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final msg = await _service.requisitionPart(
        partId: partId, vehicleId: vehicleId,
        quantity: quantity, reason: reason,
      );
      state = AsyncValue.data(msg);
      return msg;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> confirmRequisition(int reqId) async {
    state = const AsyncValue.loading();
    try {
      await _service.confirmRequisition(reqId);
      state = const AsyncValue.data('已出库');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> rejectRequisition(int reqId) async {
    state = const AsyncValue.loading();
    try {
      await _service.rejectRequisition(reqId);
      state = const AsyncValue.data('已驳回');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deletePart(int partId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deletePart(partId);
      state = const AsyncValue.data('已删除');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> updateThreshold(int partId, int threshold) async {
    state = const AsyncValue.loading();
    try {
      final msg = await _service.updateThreshold(partId, threshold);
      state = AsyncValue.data(msg);
      return msg;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final inspectionActionsProvider = StateNotifierProvider<InspectionActions, AsyncValue<String?>>((ref) {
  return InspectionActions();
});

// ==================== 参数类 ====================

class AllRecordsParams {
  final String? date;
  final int? vehicleId;
  final int? driverId;
  final int page;
  AllRecordsParams({this.date, this.vehicleId, this.driverId, this.page = 1});
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllRecordsParams && date == other.date && vehicleId == other.vehicleId && driverId == other.driverId && page == other.page;
  @override
  int get hashCode => Object.hash(date, vehicleId, driverId, page);
}

class AttendanceReportParams {
  final String month;
  final int? driverId;
  final int? departmentId;
  AttendanceReportParams({required this.month, this.driverId, this.departmentId});
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AttendanceReportParams && month == other.month && driverId == other.driverId && departmentId == other.departmentId;
  @override
  int get hashCode => Object.hash(month, driverId, departmentId);
}

class WorkHoursParams {
  final String month;
  final int? driverId;
  final int? departmentId;
  WorkHoursParams({required this.month, this.driverId, this.departmentId});
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WorkHoursParams && month == other.month && driverId == other.driverId && departmentId == other.departmentId;
  @override
  int get hashCode => Object.hash(month, driverId, departmentId);
}

class RequisitionParams {
  final String? dateFrom;
  final String? dateTo;
  final int? userId;
  RequisitionParams({this.dateFrom, this.dateTo, this.userId});
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RequisitionParams && dateFrom == other.dateFrom && dateTo == other.dateTo && userId == other.userId;
  @override
  int get hashCode => Object.hash(dateFrom, dateTo, userId);
}
