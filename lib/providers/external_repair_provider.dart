import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/external_repair_order.dart';
import '../services/external_repair_service.dart';
import 'ticker.dart';

final externalRepairServiceProvider = Provider<ExternalRepairService>((ref) => ExternalRepairService());

// ==================== 数据查询 Providers ====================

/// 共用：修理厂列表
final externalShopsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(externalRepairServiceProvider).getShops();
});

/// 共用：部门列表
final externalDepartmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(externalRepairServiceProvider).getDepartments();
});

/// 报修人：我的外修单（30秒自动刷新）
final externalMyRequestsProvider = FutureProvider.family<List<ExternalRepairOrder>, String?>((ref, status) async {
  ref.watch(listTickerProvider);
  return ref.read(externalRepairServiceProvider).getMyRequests(status: status);
});

/// 修理厂：待接单（30秒自动刷新）
final externalPendingAcceptProvider = FutureProvider<List<ExternalRepairOrder>>((ref) async {
  ref.watch(listTickerProvider);
  return ref.read(externalRepairServiceProvider).getPendingAccept();
});

/// 修理厂：我的外修工单（30秒自动刷新）
final externalShopOrdersProvider = FutureProvider.family<List<ExternalRepairOrder>, String?>((ref, status) async {
  ref.watch(listTickerProvider);
  return ref.read(externalRepairServiceProvider).getShopOrders(status: status);
});

/// 领导：待审批（30秒自动刷新）
final externalPendingApprovalProvider = FutureProvider<List<ExternalRepairOrder>>((ref) async {
  ref.watch(listTickerProvider);
  return ref.read(externalRepairServiceProvider).getPendingApproval();
});

/// 全部外修工单（分页）
class ExternalAllOrdersParams {
  final String? status;
  final int? departmentId;
  final int? repairShopId;
  final String? dateFrom;
  final String? dateTo;
  final String? keyword;
  final int page;
  ExternalAllOrdersParams({this.status, this.departmentId, this.repairShopId, this.dateFrom, this.dateTo, this.keyword, this.page = 1});
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExternalAllOrdersParams &&
          status == other.status &&
          departmentId == other.departmentId &&
          repairShopId == other.repairShopId &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo &&
          keyword == other.keyword &&
          page == other.page;
  @override
  int get hashCode => Object.hash(status, departmentId, repairShopId, dateFrom, dateTo, keyword, page);
}

final externalAllOrdersProvider = FutureProvider.family<ExternalOrderListResult, ExternalAllOrdersParams>((ref, params) async {
  return ref.read(externalRepairServiceProvider).getAllOrders(
    status: params.status,
    departmentId: params.departmentId,
    repairShopId: params.repairShopId,
    dateFrom: params.dateFrom,
    dateTo: params.dateTo,
    keyword: params.keyword,
    page: params.page,
  );
});

/// 工单详情
final externalOrderDetailProvider = FutureProvider.family<ExternalOrderDetailResult, int>((ref, orderId) async {
  return ref.read(externalRepairServiceProvider).getOrderDetail(orderId);
});

// ==================== 操作 Notifier ====================

class ExternalRepairActions extends StateNotifier<AsyncValue<void>> {
  final ExternalRepairService _service = ExternalRepairService();

  ExternalRepairActions() : super(const AsyncValue.data(null));

  Future<String> reportFault({
    required String vehicleName,
    required String faultDescription,
    List<String>? faultImages,
    String? departmentName,
    int? repairShopId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final no = await _service.reportFault(
        vehicleName: vehicleName,
        faultDescription: faultDescription,
        faultImages: faultImages,
        departmentName: departmentName,
        repairShopId: repairShopId,
      );
      state = const AsyncValue.data(null);
      return no;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> acceptAndQuote({
    required int orderId,
    required double quoteAmount,
    double partsCost = 0,
    double laborCost = 0,
    double hoursCost = 0,
    List<Map<String, dynamic>>? partsList,
    String? quoteDetail,
    int? estimatedDays,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.acceptAndQuote(
        orderId: orderId,
        quoteAmount: quoteAmount,
        partsCost: partsCost,
        laborCost: laborCost,
        hoursCost: hoursCost,
        partsList: partsList,
        quoteDetail: quoteDetail,
        estimatedDays: estimatedDays,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateProgress({required int orderId, required String content, List<String>? images}) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateProgress(orderId: orderId, content: content, images: images);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeOrder(int orderId) async {
    state = const AsyncValue.loading();
    try {
      await _service.completeOrder(orderId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> approveQuote({required int orderId, required bool approved, String? rejectReason}) async {
    state = const AsyncValue.loading();
    try {
      await _service.approveQuote(orderId: orderId, approved: approved, rejectReason: rejectReason);
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

  Future<void> acceptCompletion(int orderId) async {
    state = const AsyncValue.loading();
    try {
      await _service.acceptCompletion(orderId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final externalRepairActionsProvider = StateNotifierProvider<ExternalRepairActions, AsyncValue<void>>((ref) {
  return ExternalRepairActions();
});
