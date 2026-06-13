/// 配件库存
class PartItem {
  final int id;
  final String partName;
  final String? partCode;
  final int quantity;
  final String? unit;
  final double? unitPrice;
  final int threshold;
  final String? remark;
  final String? createdAt;
  final String? updatedAt;

  PartItem({
    required this.id,
    required this.partName,
    this.partCode,
    this.quantity = 0,
    this.unit,
    this.unitPrice,
    this.threshold = 5,
    this.remark,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => quantity < threshold;

  factory PartItem.fromJson(Map<String, dynamic> json) {
    return PartItem(
      id: json['id'] as int? ?? 0,
      partName: (json['part_name'] ?? '') as String,
      partCode: json['part_code'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      unit: json['unit'] as String?,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      threshold: json['threshold'] as int? ?? 5,
      remark: json['remark'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// 配件领用记录
class PartRequisition {
  final int id;
  final int userId;
  final int partId;
  final int? vehicleId;
  final int quantity;
  final String? reason;
  final String status; // pending, completed, rejected
  final int? approvedBy;
  final String? pickedUpAt;

  // JOIN 字段
  final String? partName;
  final String? partCode;
  final String? userName;
  final String? plateNumber;

  final String? createdAt;
  final String? updatedAt;

  PartRequisition({
    required this.id,
    required this.userId,
    required this.partId,
    this.vehicleId,
    required this.quantity,
    this.reason,
    this.status = 'pending',
    this.approvedBy,
    this.pickedUpAt,
    this.partName,
    this.partCode,
    this.userName,
    this.plateNumber,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'pending': return '待确认';
      case 'completed': return '已出库';
      case 'rejected': return '已驳回';
      default: return status;
    }
  }

  factory PartRequisition.fromJson(Map<String, dynamic> json) {
    return PartRequisition(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      partId: json['part_id'] as int? ?? 0,
      vehicleId: json['vehicle_id'] as int?,
      quantity: json['quantity'] as int? ?? 0,
      reason: json['reason'] as String?,
      status: (json['status'] ?? 'pending') as String,
      approvedBy: json['approved_by'] as int?,
      pickedUpAt: json['picked_up_at'] as String?,
      partName: json['part_name'] as String?,
      partCode: json['part_code'] as String?,
      userName: json['user_name'] as String?,
      plateNumber: json['plate_number'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}
