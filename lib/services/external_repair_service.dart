import '../models/external_repair_order.dart';
import 'http_client.dart';

class ExternalRepairService {
  final HttpClient _client = HttpClient();

  // ==================== 共用 ====================

  Future<List<Map<String, dynamic>>> getShops() async {
    final resp = await _client.get('/external-repair/shops');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取修理厂列表失败');
    return (resp.data as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final resp = await _client.get('/external-repair/departments');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取部门列表失败');
    return (resp.data as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }

  // ==================== 报修人端 ====================

  Future<String> reportFault({
    required String vehicleName,
    required String faultDescription,
    List<String>? faultImages,
    String? departmentName,
    int? repairShopId,
  }) async {
    final resp = await _client.post('/external-repair/report', data: {
      'vehicle_name': vehicleName,
      'fault_description': faultDescription,
      'fault_images': faultImages ?? [],
      'department_name': departmentName ?? '',
      if (repairShopId != null) 'repair_shop_id': repairShopId,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '提交失败');
    return (resp.data as Map<String, dynamic>?)?['order_no']?.toString() ?? '';
  }

  Future<List<ExternalRepairOrder>> getMyRequests({String? status}) async {
    final resp = await _client.get('/external-repair/my-requests',
        queryParams: status != null ? {'status': status} : null);
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => ExternalRepairOrder.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> acceptCompletion(int orderId) async {
    final resp = await _client.post('/external-repair/accept-completion/$orderId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '验收失败');
  }

  // ==================== 修理厂端 ====================

  Future<List<ExternalRepairOrder>> getPendingAccept() async {
    final resp = await _client.get('/external-repair/pending-accept');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => ExternalRepairOrder.fromJson(r as Map<String, dynamic>)).toList();
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
    final resp = await _client.post('/external-repair/accept-order/$orderId', data: {
      'quote_amount': quoteAmount,
      'parts_cost': partsCost,
      'labor_cost': laborCost,
      'hours_cost': hoursCost,
      'parts_list': partsList ?? [],
      'quote_detail': quoteDetail ?? '',
      'estimated_days': estimatedDays,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
  }

  Future<List<ExternalRepairOrder>> getShopOrders({String? status}) async {
    final resp = await _client.get('/external-repair/shop-orders',
        queryParams: status != null ? {'status': status} : null);
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => ExternalRepairOrder.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> updateProgress({
    required int orderId,
    required String content,
    List<String>? images,
  }) async {
    final resp = await _client.post('/external-repair/update-progress/$orderId', data: {
      'content': content,
      'images': images ?? [],
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
  }

  Future<void> completeOrder(int orderId) async {
    final resp = await _client.post('/external-repair/complete/$orderId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
  }

  // ==================== 领导/管理员端 ====================

  Future<List<ExternalRepairOrder>> getPendingApproval() async {
    final resp = await _client.get('/external-repair/pending-approval');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((r) => ExternalRepairOrder.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> approveQuote({
    required int orderId,
    required bool approved,
    String? rejectReason,
  }) async {
    final resp = await _client.post('/external-repair/approve/$orderId', data: {
      'approved': approved,
      if (rejectReason != null) 'reject_reason': rejectReason,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
  }

  Future<void> markUrgent(int orderId) async {
    final resp = await _client.post('/external-repair/urgent/$orderId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '操作失败');
  }

  Future<ExternalOrderListResult> getAllOrders({
    String? status,
    int? departmentId,
    int? repairShopId,
    String? dateFrom,
    String? dateTo,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.get('/external-repair/all-orders', queryParams: {
      if (status != null) 'status': status,
      if (departmentId != null) 'department_id': departmentId,
      if (repairShopId != null) 'repair_shop_id': repairShopId,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (keyword != null) 'keyword': keyword,
      'page': page,
      'pageSize': pageSize,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取列表失败');
    final data = resp.data as Map<String, dynamic>? ?? {};
    final list = (data['list'] as List<dynamic>?)?.map((r) => ExternalRepairOrder.fromJson(r as Map<String, dynamic>)).toList() ?? [];
    return ExternalOrderListResult(
      list: list,
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? 1,
      pageSize: data['pageSize'] as int? ?? 20,
    );
  }

  // ==================== 共用 ====================

  Future<ExternalOrderDetailResult> getOrderDetail(int orderId) async {
    final resp = await _client.get('/external-repair/detail/$orderId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取详情失败');
    final data = resp.data as Map<String, dynamic>? ?? {};
    final order = ExternalRepairOrder.fromJson(data['order'] as Map<String, dynamic>? ?? {});
    final progressList = (data['progress'] as List<dynamic>?)?.map((r) => ExternalRepairProgress.fromJson(r as Map<String, dynamic>)).toList() ?? [];
    return ExternalOrderDetailResult(order: order, progress: progressList);
  }
}
