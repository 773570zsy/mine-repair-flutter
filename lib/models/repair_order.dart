class RepairOrder {
  final int id;
  final int driverId;
  final int? vehicleId;
  final int? repairShopId;
  final String orderNo;
  final String faultDescription;
  final String status;
  final String? rejectReason;
  final bool isUrgent;

  // 关联字段（JOIN）
  final String? plateNumber;
  final String? vehicleType;
  final String? driverName;
  final String? driverPhone;
  final String? repairShopName;
  final String? deptName;

  // 报价字段（JOIN repair_quotes）
  final double? quoteAmount;
  final double? partsCost;
  final double? laborCost;
  final double? hoursCost;
  final String? partsList; // JSON string
  final String? quoteDetail;
  final int? estimatedDays;
  final String? approvedAt;

  // 照片
  final List<String> faultImages;
  final List<String> damagePhotos;  // 报价时拍的损坏配件照片
  final List<String> newPhotos;     // 完工时上传的新配件照片

  // 时间
  final String? createdAt;
  final String? updatedAt;

  // 分页总量
  final int? total;

  RepairOrder({
    required this.id,
    required this.driverId,
    this.vehicleId,
    this.repairShopId,
    required this.orderNo,
    required this.faultDescription,
    required this.status,
    this.rejectReason,
    this.isUrgent = false,
    this.plateNumber,
    this.vehicleType,
    this.driverName,
    this.driverPhone,
    this.repairShopName,
    this.deptName,
    this.quoteAmount,
    this.partsCost,
    this.laborCost,
    this.hoursCost,
    this.partsList,
    this.quoteDetail,
    this.estimatedDays,
    this.approvedAt,
    this.faultImages = const [],
    this.damagePhotos = const [],
    this.newPhotos = const [],
    this.createdAt,
    this.updatedAt,
    this.total,
  });

  // 状态判断
  bool get isPendingAccept => status == 'pending_accept';
  bool get isPendingQuote => status == 'pending_quote';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isRepairing => status == 'repairing';
  bool get isCompleted => status == 'completed';
  bool get isAccepted => status == 'accepted';
  bool get isCancelled => status == 'cancelled';

  // 修理厂可操作的状态
  bool get canAccept => isPendingAccept;
  bool get canQuote => isPendingQuote;
  bool get canUpdateProgress => isApproved || isRepairing;
  bool get canComplete => isApproved || isRepairing;

  // 驾驶员可验收
  bool get canVerify => isCompleted;

  // 领导可审批
  bool get canApprove => isPendingApproval;

  static List<String> parseJsonStringArray(dynamic val) {
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String && val.isNotEmpty) {
      try {
        final parsed = List<dynamic>.from(
          (RegExp(r'\[(.*)\]').firstMatch(val)?.group(1) ?? '').split(',').map((s) => s.trim().replaceAll('"', '').replaceAll("'", '')).where((s) => s.isNotEmpty),
        );
        return parsed.cast<String>();
      } catch (_) {
        return val.isNotEmpty ? [val] : [];
      }
    }
    return [];
  }

  static List<String> parseJsonStringList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list =
          RegExp(r'\[.*\]').firstMatch(jsonStr)?.group(0) != null
              ? List<dynamic>.from(
                  (RegExp(r'\[(.*)\]').firstMatch(jsonStr)?.group(1) ?? '')
                      .split(',')
                      .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
                      .where((s) => s.isNotEmpty))
              : [];
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  factory RepairOrder.fromJson(Map<String, dynamic> json) {
    // Parse fault_images: could be JSON string or already a List
    List<String> images = [];
    final fi = json['fault_images'];
    if (fi is List) {
      images = fi.map((e) => e.toString()).toList();
    } else if (fi is String && fi.isNotEmpty) {
      try {
        final parsed = List<dynamic>.from(
          (RegExp(r'\[(.*)\]')
                  .firstMatch(fi)
                  ?.group(1) ?? '')
              .split(',')
              .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((s) => s.isNotEmpty),
        );
        images = parsed.cast<String>();
      } catch (_) {
        images = fi.isNotEmpty ? [fi] : [];
      }
    }

    return RepairOrder(
      id: json['id'] as int? ?? 0,
      driverId: json['driver_id'] as int? ?? 0,
      vehicleId: json['vehicle_id'] as int?,
      repairShopId: json['repair_shop_id'] as int?,
      orderNo: (json['order_no'] ?? '') as String,
      faultDescription: (json['fault_description'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      rejectReason: json['reject_reason'] as String?,
      isUrgent: (json['is_urgent'] as int? ?? 0) == 1,
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      repairShopName: json['repair_shop_name'] as String?,
      deptName: json['dept_name'] as String?,
      quoteAmount: (json['quote_amount'] as num?)?.toDouble(),
      partsCost: (json['parts_cost'] as num?)?.toDouble(),
      laborCost: (json['labor_cost'] as num?)?.toDouble(),
      hoursCost: (json['hours_cost'] as num?)?.toDouble(),
      partsList: json['parts_list'] as String?,
      quoteDetail: json['quote_detail'] as String?,
      estimatedDays: json['estimated_days'] as int?,
      approvedAt: json['approved_at'] as String?,
      faultImages: images,
      damagePhotos: parseJsonStringArray(json['damage_photos']),
      newPhotos: parseJsonStringArray(json['new_photos']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      total: json['total'] as int?,
    );
  }
}

/// 维修进度记录
class RepairProgress {
  final int id;
  final int orderId;
  final int userId;
  final String action;
  final String content;
  final String? createdAt;
  final String? userName;
  final String? userRole;
  final List<String> images;

  RepairProgress({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.action,
    required this.content,
    this.createdAt,
    this.userName,
    this.userRole,
    this.images = const [],
  });

  factory RepairProgress.fromJson(Map<String, dynamic> json) {
    List<String> imgs = [];
    final img = json['images'];
    if (img is List) {
      imgs = img.map((e) => e.toString()).toList();
    } else if (img is String && img.isNotEmpty) {
      try {
        imgs = List<String>.from(
          (RegExp(r'\[(.*)\]')
                  .firstMatch(img)
                  ?.group(1) ?? '')
              .split(',')
              .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((s) => s.isNotEmpty),
        );
      } catch (_) {}
    }

    return RepairProgress(
      id: json['id'] as int? ?? 0,
      orderId: json['order_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      action: (json['action'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      createdAt: json['created_at'] as String?,
      userName: json['user_name'] as String?,
      userRole: json['user_role'] as String?,
      images: imgs,
    );
  }
}
