import '../models/repair_order.dart';
import 'http_client.dart';

class RepairService {
  final HttpClient _client = HttpClient();

  // ==================== 驾驶员端 ====================

  /// 发起报修
  Future<String> reportFault({
    required int vehicleId,
    required String faultDescription,
    List<String>? faultImages,
    int? repairShopId,
  }) async {
    final resp = await _client.post('/repair/report', data: {
      'vehicle_id': vehicleId,
      'fault_description': faultDescription,
      'fault_images': faultImages ?? [],
      if (repairShopId != null) 'repair_shop_id': repairShopId,
    });
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '报修失败');
    }
    final data = resp.data as Map<String, dynamic>;
    return data['order_no'] as String;
  }

  /// 驾驶员-查看我的报修列表
  Future<List<RepairOrder>> getMyOrders({String? status}) async {
    final resp = await _client.get('/repair/my-orders',
        queryParams: status != null ? {'status': status} : null);
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '获取工单列表失败');
    }
    final list = resp.data as List<dynamic>? ?? [];
    return list
        .map((o) => RepairOrder.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  /// 驾驶员-试车验收
  Future<void> acceptOrder(int orderId, {String? content}) async {
    final resp = await _client.post('/repair/accept/$orderId', data: {
      'content': content ?? '',
    });
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '验收失败');
    }
  }

  // ==================== 修理厂端 ====================

  /// 待接单列表
  Future<List<RepairOrder>> getPendingAccept() async {
    final resp = await _client.get('/repair/pending-accept');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取待接单列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list
        .map((o) => RepairOrder.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  /// 修理厂-接单
  Future<void> acceptRepairOrder(int orderId) async {
    final resp = await _client.post('/repair/accept-order/$orderId');
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '接单失败');
    }
  }

  /// 修理厂-查看我的工单
  Future<List<RepairOrder>> getShopOrders({String? status}) async {
    final resp = await _client.get('/repair/shop-orders',
        queryParams: status != null ? {'status': status} : null);
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取工单列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list
        .map((o) => RepairOrder.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  /// 提交报价
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
    final resp = await _client.post('/repair/submit-quote/$orderId', data: {
      'quote_amount': quoteAmount,
      'parts_cost': partsCost ?? 0,
      'labor_cost': laborCost ?? 0,
      'hours_cost': hoursCost ?? 0,
      'parts_list': partsList ?? [],
      'quote_detail': quoteDetail ?? '',
      'estimated_days': estimatedDays,
      'damage_photos': damagePhotos ?? [],
    });
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '提交报价失败');
    }
  }

  /// 更新维修进度
  Future<void> updateProgress({
    required int orderId,
    required String content,
    List<String>? images,
  }) async {
    final resp = await _client.post('/repair/update-progress/$orderId', data: {
      'content': content,
      'images': images ?? [],
    });
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '更新进度失败');
    }
  }

  /// 完工
  Future<void> completeOrder(int orderId, {List<String>? newPhotos}) async {
    final resp = await _client.post('/repair/complete/$orderId', data: {
      'new_photos': newPhotos ?? [],
    });
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '操作失败');
    }
  }

  // ==================== 领导/管理员端 ====================

  /// 待审批报价列表
  Future<List<RepairOrder>> getPendingApproval() async {
    final resp = await _client.get('/repair/pending-approval');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取待审批列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list
        .map((o) => RepairOrder.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  /// 审批报价
  Future<void> approveQuote({
    required int orderId,
    required bool approved,
    String? rejectReason,
  }) async {
    final resp = await _client.post('/repair/approve/$orderId', data: {
      'approved': approved,
      if (!approved) 'reject_reason': rejectReason ?? '',
    });
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '审批操作失败');
    }
  }

  /// 标记加急
  Future<void> markUrgent(int orderId) async {
    final resp = await _client.post('/repair/urgent/$orderId');
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '操作失败');
    }
  }

  /// 全部维修记录（分页）
  Future<RepairOrderListResult> getAllOrders({
    String? status,
    int? vehicleId,
    String? dateFrom,
    String? dateTo,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (status != null) params['status'] = status;
    if (vehicleId != null) params['vehicle_id'] = vehicleId;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

    final resp = await _client.get('/repair/all-orders', queryParams: params);
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取工单列表失败');

    final data = resp.data as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>? ?? [])
        .map((o) => RepairOrder.fromJson(o as Map<String, dynamic>))
        .toList();

    return RepairOrderListResult(
      list: list,
      total: data['total'] as int? ?? list.length,
      page: data['page'] as int? ?? page,
      pageSize: data['pageSize'] as int? ?? pageSize,
    );
  }

  // ==================== 通用 ====================

  /// 工单详情（含进度时间线）
  Future<OrderDetailResult> getOrderDetail(int orderId) async {
    final resp = await _client.get('/repair/detail/$orderId');
    if (!resp.isSuccess || resp.data == null) {
      throw Exception(resp.msg ?? '获取工单详情失败');
    }
    final data = resp.data as Map<String, dynamic>;
    final order =
        RepairOrder.fromJson(data['order'] as Map<String, dynamic>);
    final progressList = (data['progress'] as List<dynamic>? ?? [])
        .map((p) => RepairProgress.fromJson(p as Map<String, dynamic>))
        .toList();

    return OrderDetailResult(order: order, progress: progressList);
  }
}

/// 工单列表分页结果
class RepairOrderListResult {
  final List<RepairOrder> list;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  RepairOrderListResult({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

/// 工单详情结果
class OrderDetailResult {
  final RepairOrder order;
  final List<RepairProgress> progress;

  OrderDetailResult({required this.order, required this.progress});
}
