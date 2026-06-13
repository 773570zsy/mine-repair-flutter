import '../config/constants.dart';

class User {
  final int id;
  final String name;
  final String phone;
  final String role;
  final int? repairShopId;
  final int? departmentId;
  final String? deptName;
  final String? shopName;
  final int status;

  User({
    required this.id,
    required this.name,
    this.phone = '',
    required this.role,
    this.repairShopId,
    this.departmentId,
    this.deptName,
    this.shopName,
    this.status = 1,
  });

  String get roleLabel => roleMap[role] ?? role;
  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isRepairShop => role == 'repair_shop';
  bool get isLeader => role == 'leader';
  bool get isSafetyOfficer => role == 'safety_officer';
  bool get isDispatcher => role == 'dispatcher';
  bool get isApplicant => role == 'applicant';
  bool get isExternalRepair => role == 'external_repair';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      repairShopId: json['repair_shop_id'] as int?,
      departmentId: json['department_id'] as int?,
      deptName: json['dept_name'] as String?,
      shopName: json['shop_name'] as String?,
      status: (json['status'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'role': role,
    'repair_shop_id': repairShopId, 'department_id': departmentId,
    'dept_name': deptName, 'shop_name': shopName, 'status': status,
  };

}

/// 登录响应中的绑定信息
class UserBinding {
  final int id;
  final int vehicleId;
  final String plateNumber;
  final String? vehicleType;

  UserBinding({
    required this.id,
    required this.vehicleId,
    required this.plateNumber,
    this.vehicleType,
  });

  factory UserBinding.fromJson(Map<String, dynamic> json) {
    return UserBinding(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      plateNumber: json['plate_number'] as String,
      vehicleType: json['vehicle_type'] as String?,
    );
  }
}
