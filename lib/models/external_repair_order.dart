/// 外部报修订单
class ExternalRepairOrder {
  final int id;
  final String orderNo;
  final int departmentId;
  final int userId;
  final int? repairShopId;
  final String vehicleName;
  final String faultDescription;
  final String status;
  final String? rejectReason;
  final bool isUrgent;

  // 报价字段（反规范化，直接存在订单上）
  final double? quoteAmount;
  final double? partsCost;
  final double? laborCost;
  final double? hoursCost;
  final String? partsList; // JSON string
  final String? quoteDetail;
  final int? estimatedDays;
  final int? leaderId;
  final String? approvedAt;

  // 部门名称（文本，自由填写）
  final String? departmentName;

  // JOIN 字段
  final String? repairShopName;
  final String? deptName;
  final String? userName;

  // 照片
  final List<String> faultImages;

  // 时间
  final String? createdAt;
  final String? updatedAt;

  ExternalRepairOrder({
    required this.id,
    required this.orderNo,
    required this.departmentId,
    required this.userId,
    this.repairShopId,
    required this.vehicleName,
    required this.faultDescription,
    required this.status,
    this.rejectReason,
    this.isUrgent = false,
    this.quoteAmount,
    this.partsCost,
    this.laborCost,
    this.hoursCost,
    this.partsList,
    this.quoteDetail,
    this.estimatedDays,
    this.leaderId,
    this.approvedAt,
    this.departmentName,
    this.repairShopName,
    this.deptName,
    this.userName,
    this.faultImages = const [],
    this.createdAt,
    this.updatedAt,
  });

  // ===== 状态便捷 getter =====

  bool get isPendingAccept => status == 'pending_accept';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isRepairing => status == 'repairing';
  bool get isCompleted => status == 'completed';
  bool get isAccepted => status == 'accepted';
  bool get isCancelled => status == 'cancelled';

  // 修理厂操作权限
  bool get canAccept => isPendingAccept;
  bool get canUpdateProgress => isApproved || isRepairing;
  bool get canComplete => isApproved || isRepairing;

  // 领导操作权限
  bool get canApprove => isPendingApproval;

  // 报修人操作权限
  bool get canVerify => isCompleted;

  factory ExternalRepairOrder.fromJson(Map<String, dynamic> json) {
    List<String> parsePhotos(dynamic p) {
      if (p is List) return p.map((e) => e.toString()).toList();
      if (p is String && p.isNotEmpty) {
        try {
          final decoded = List<dynamic>.from(
            (RegExp(r'\[(.*)\]').firstMatch(p)?.group(1) ?? '')
                .split(',')
                .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((s) => s.isNotEmpty),
          );
          if (decoded.isNotEmpty) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return ExternalRepairOrder(
      id: json['id'] as int? ?? 0,
      orderNo: (json['order_no'] ?? '') as String,
      departmentId: json['department_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      repairShopId: json['repair_shop_id'] as int?,
      vehicleName: (json['vehicle_name'] ?? '') as String,
      faultDescription: (json['fault_description'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      rejectReason: json['reject_reason'] as String?,
      isUrgent: (json['is_urgent'] as int? ?? 0) == 1,
      quoteAmount: (json['quote_amount'] as num?)?.toDouble(),
      partsCost: (json['parts_cost'] as num?)?.toDouble(),
      laborCost: (json['labor_cost'] as num?)?.toDouble(),
      hoursCost: (json['hours_cost'] as num?)?.toDouble(),
      partsList: json['parts_list'] as String?,
      quoteDetail: json['quote_detail'] as String?,
      estimatedDays: json['estimated_days'] as int?,
      leaderId: json['leader_id'] as int?,
      approvedAt: json['approved_at'] as String?,
      departmentName: json['department_name'] as String?,
      repairShopName: json['repair_shop_name'] as String?,
      deptName: json['dept_name'] as String?,
      userName: json['user_name'] as String?,
      faultImages: parsePhotos(json['fault_images']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// 外部维修进度
class ExternalRepairProgress {
  final int id;
  final int orderId;
  final int userId;
  final String action;
  final String? content;
  final List<String> images;
  final String? userName;
  final String? createdAt;

  ExternalRepairProgress({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.action,
    this.content,
    this.images = const [],
    this.userName,
    this.createdAt,
  });

  factory ExternalRepairProgress.fromJson(Map<String, dynamic> json) {
    List<String> parsePhotos(dynamic p) {
      if (p is List) return p.map((e) => e.toString()).toList();
      if (p is String && p.isNotEmpty) {
        try {
          final decoded = List<dynamic>.from(
            (RegExp(r'\[(.*)\]').firstMatch(p)?.group(1) ?? '')
                .split(',')
                .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((s) => s.isNotEmpty),
          );
          if (decoded.isNotEmpty) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return ExternalRepairProgress(
      id: json['id'] as int? ?? 0,
      orderId: json['order_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      action: (json['action'] ?? '') as String,
      content: json['content'] as String?,
      images: parsePhotos(json['images']),
      userName: json['user_name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// 列表分页结果
class ExternalOrderListResult {
  final List<ExternalRepairOrder> list;
  final int total;
  final int page;
  final int pageSize;

  ExternalOrderListResult({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

/// 工单详情结果
class ExternalOrderDetailResult {
  final ExternalRepairOrder order;
  final List<ExternalRepairProgress> progress;

  ExternalOrderDetailResult({
    required this.order,
    required this.progress,
  });
}

/// 状态映射（外部维修无 pending_quote）
const externalStatusMap = {
  'pending_accept': '待接单',
  'pending_approval': '待审批',
  'approved': '已通过',
  'rejected': '已驳回',
  'repairing': '维修中',
  'completed': '待验收',
  'accepted': '已完成',
  'cancelled': '已取消',
};

/// 外部维修进度动作名称
const externalActionNameMap = {
  'accepted_order': '接单并报价',
  'progress_update': '进度更新',
  'completed': '维修完成',
  'accepted': '验收通过',
  'approved': '审批通过',
  'rejected': '审批驳回',
  'urgent': '标记加急',
};
