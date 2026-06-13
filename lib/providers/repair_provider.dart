import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/repair_order.dart';
import '../services/vehicle_service.dart';
import '../services/repair_service.dart';

// ==================== 车辆 ====================

final vehicleListProvider = FutureProvider<List<Vehicle>>((ref) async {
  final service = VehicleService();
  return service.getVehicles();
});

// ==================== 工单列表 Providers ====================

/// 驾驶员-我的工单
final myOrdersProvider =
    FutureProvider.family<List<RepairOrder>, String?>((ref, status) async {
  final service = RepairService();
  return service.getMyOrders(status: status);
});

/// 修理厂-待接单
final pendingAcceptProvider = FutureProvider<List<RepairOrder>>((ref) async {
  final service = RepairService();
  return service.getPendingAccept();
});

/// 修理厂-我的工单
final shopOrdersProvider =
    FutureProvider.family<List<RepairOrder>, String?>((ref, status) async {
  final service = RepairService();
  return service.getShopOrders(status: status);
});

/// 领导/管理员-待审批
final pendingApprovalProvider = FutureProvider<List<RepairOrder>>((ref) async {
  final service = RepairService();
  return service.getPendingApproval();
});

// ==================== 全部工单（分页） ====================

class AllOrdersParams {
  final String? status;
  final int? vehicleId;
  final String? dateFrom;
  final String? dateTo;
  final String? keyword;
  final int page;

  AllOrdersParams({
    this.status,
    this.vehicleId,
    this.dateFrom,
    this.dateTo,
    this.keyword,
    this.page = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllOrdersParams &&
          status == other.status &&
          vehicleId == other.vehicleId &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo &&
          keyword == other.keyword &&
          page == other.page;

  @override
  int get hashCode => Object.hash(status, vehicleId, dateFrom, dateTo, keyword, page);
}

final allOrdersProvider =
    FutureProvider.family<RepairOrderListResult, AllOrdersParams>(
        (ref, params) async {
  final service = RepairService();
  return service.getAllOrders(
    status: params.status,
    vehicleId: params.vehicleId,
    dateFrom: params.dateFrom,
    dateTo: params.dateTo,
    keyword: params.keyword,
    page: params.page,
  );
});

// ==================== 工单详情 ====================

final orderDetailProvider =
    FutureProvider.family<OrderDetailResult, int>((ref, orderId) async {
  final service = RepairService();
  return service.getOrderDetail(orderId);
});

// ==================== 操作 Notifier（用于刷新列表） ====================

class RepairActions extends StateNotifier<AsyncValue<void>> {
  final RepairService _service = RepairService();

  RepairActions() : super(const AsyncValue.data(null));

  Future<void> reportFault({
    required int vehicleId,
    required String faultDescription,
    List<String>? faultImages,
    int? repairShopId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.reportFault(
        vehicleId: vehicleId,
        faultDescription: faultDescription,
        faultImages: faultImages,
        repairShopId: repairShopId,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> acceptRepairOrder(int orderId) async {
    state = const AsyncValue.loading();
    try {
      await _service.acceptRepairOrder(orderId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> submitQuote({
    required int orderId,
    required double quoteAmount,
    double? partsCost,
    double? laborCost,
    double? hoursCost,
    List<Map<String, dynamic>>? partsList,
    String? quoteDetail,
    int? estimatedDays,
    List<String>? damagePhotos,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.submitQuote(
        orderId: orderId,
        quoteAmount: quoteAmount,
        partsCost: partsCost,
        laborCost: laborCost,
        hoursCost: hoursCost,
        partsList: partsList,
        quoteDetail: quoteDetail,
        estimatedDays: estimatedDays,
        damagePhotos: damagePhotos,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateProgress({
    required int orderId,
    required String content,
    List<String>? images,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateProgress(
        orderId: orderId,
        content: content,
        images: images,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeOrder(int orderId, {List<String>? newPhotos}) async {
    state = const AsyncValue.loading();
    try {
      await _service.completeOrder(orderId, newPhotos: newPhotos);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> approveQuote({
    required int orderId,
    required bool approved,
    String? rejectReason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.approveQuote(
        orderId: orderId,
        approved: approved,
        rejectReason: rejectReason,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> markUrgent(int orderId) async {
    state = const AsyncValue.loading();
    try {
      await _service.markUrgent(orderId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifyOrder(int orderId, {String? content}) async {
    state = const AsyncValue.loading();
    try {
      await _service.acceptOrder(orderId, content: content);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final repairActionsProvider =
    StateNotifierProvider<RepairActions, AsyncValue<void>>((ref) {
  return RepairActions();
});
