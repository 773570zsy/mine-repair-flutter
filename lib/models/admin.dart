import 'dart:convert';
import '../config/constants.dart';

int _parseInt(dynamic v, int fallback) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _parseDouble(dynamic v, double fallback) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

/// 用户管理模型
class AdminUser {
  final int id;
  final String name;
  final String phone;
  final String role;
  final int? repairShopId;
  final int? departmentId;
  final String? deptName;
  final String? shopName;
  final int status;
  final String createdAt;

  AdminUser({
    required this.id,
    required this.name,
    this.phone = '',
    required this.role,
    this.repairShopId,
    this.departmentId,
    this.deptName,
    this.shopName,
    this.status = 1,
    this.createdAt = '',
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      repairShopId: json['repair_shop_id'] as int?,
      departmentId: json['department_id'] as int?,
      deptName: json['dept_name'] as String?,
      shopName: json['shop_name'] as String?,
      status: _parseInt(json['status'], 1),
      createdAt: (json['created_at'] ?? '') as String,
    );
  }

  String get roleLabel => roleMap[role] ?? role;
}

/// 部门
class Department {
  final int id;
  final String name;

  Department({required this.id, required this.name});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(id: json['id'] as int, name: (json['name'] ?? '') as String);
  }
}

/// 修理厂
class RepairShop {
  final int id;
  final String name;
  final String contactPerson;
  final String contactPhone;
  final String? remark;
  final int status;

  RepairShop({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.contactPhone = '',
    this.remark,
    this.status = 1,
  });

  factory RepairShop.fromJson(Map<String, dynamic> json) {
    return RepairShop(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      contactPerson: (json['contact_person'] ?? '') as String,
      contactPhone: (json['contact_phone'] ?? '') as String,
      remark: json['remark'] as String?,
      status: _parseInt(json['status'], 1),
    );
  }
}

/// 车辆-驾驶员绑定
class DriverVehicleBinding {
  final int id;
  final int driverId;
  final int vehicleId;
  final String bindDate;
  final String? unbindDate;
  final String? driverName;
  final String? plateNumber;

  DriverVehicleBinding({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.bindDate,
    this.unbindDate,
    this.driverName,
    this.plateNumber,
  });

  factory DriverVehicleBinding.fromJson(Map<String, dynamic> json) {
    return DriverVehicleBinding(
      id: json['id'] as int,
      driverId: json['driver_id'] as int,
      vehicleId: json['vehicle_id'] as int,
      bindDate: (json['bind_date'] ?? '') as String,
      unbindDate: json['unbind_date'] as String?,
      driverName: json['driver_name'] as String?,
      plateNumber: json['plate_number'] as String?,
    );
  }
}

/// 仪表盘数据
class AdminDashboard {
  final int totalVehicles;
  final int normalVehicles;
  final int repairingCount;
  final int expiredCount;
  final int pendingApprovalCount;
  final int monthCount;
  final double monthlyCost;
  final List<RepairStatusStat> repairStats;
  final int maintOverdue;
  final int maintSoon;
  final int hazardOverdue;
  final int partsLowStock;

  AdminDashboard({
    this.totalVehicles = 0,
    this.normalVehicles = 0,
    this.repairingCount = 0,
    this.expiredCount = 0,
    this.pendingApprovalCount = 0,
    this.monthCount = 0,
    this.monthlyCost = 0,
    this.repairStats = const [],
    this.maintOverdue = 0,
    this.maintSoon = 0,
    this.hazardOverdue = 0,
    this.partsLowStock = 0,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    final stats = (json['repairStats'] as List<dynamic>? ?? [])
        .map((v) => RepairStatusStat.fromJson(v as Map<String, dynamic>))
        .toList();
    return AdminDashboard(
      totalVehicles: (json['totalVehicles'] ?? 0) as int,
      normalVehicles: (json['normalVehicles'] ?? 0) as int,
      repairingCount: (json['repairingCount'] ?? 0) as int,
      expiredCount: (json['expiredCount'] ?? 0) as int,
      pendingApprovalCount: (json['pendingApprovalCount'] ?? 0) as int,
      monthCount: (json['monthCount'] ?? 0) as int,
      monthlyCost: (json['monthlyCost'] ?? 0).toDouble(),
      repairStats: stats,
      maintOverdue: (json['maintOverdue'] ?? 0) as int,
      maintSoon: (json['maintSoon'] ?? 0) as int,
      hazardOverdue: (json['hazardOverdue'] ?? 0) as int,
      partsLowStock: (json['partsLowStock'] ?? 0) as int,
    );
  }

  bool get hasAlerts => maintOverdue > 0 || maintSoon > 0 || hazardOverdue > 0 || partsLowStock > 0;
}

class RepairStatusStat {
  final String status;
  final int count;

  RepairStatusStat({required this.status, required this.count});

  factory RepairStatusStat.fromJson(Map<String, dynamic> json) {
    return RepairStatusStat(
      status: (json['status'] ?? '') as String,
      count: (json['count'] ?? 0) as int,
    );
  }

  String get statusLabel => _statusLabels[status] ?? status;

  static const Map<String, String> _statusLabels = {
    'pending_accept': '待接单', 'pending_quote': '待报价', 'pending_approval': '待审批',
    'approved': '已通过', 'rejected': '已驳回', 'repairing': '维修中',
    'completed': '待验收', 'accepted': '已完成',
  };
}

/// 费用报表条目
class CostReportItem {
  final String source;
  final String orderNo;
  final String vehicleName;
  final String? vehicleType;
  final String? repairShopName;
  final String? deptName;
  final String? driverName;
  final double quoteAmount;
  final double partsCost;
  final double laborCost;
  final double hoursCost;
  final String? partsList;
  final String? quoteDetail;
  final int estimatedDays;
  final String? approvedAt;
  final String? reportDate;

  CostReportItem({required this.source, required this.orderNo, required this.vehicleName,
    this.vehicleType, this.repairShopName, this.deptName, this.driverName, this.quoteAmount=0, this.partsCost=0,
    this.laborCost=0, this.hoursCost=0, this.partsList, this.quoteDetail, this.estimatedDays=0,
    this.approvedAt, this.reportDate});

  factory CostReportItem.fromJson(Map<String, dynamic> json) {
    return CostReportItem(
      source: (json['source'] ?? '') as String,
      orderNo: (json['order_no'] ?? '') as String,
      vehicleName: (json['vehicle_name'] ?? '') as String,
      vehicleType: json['vehicle_type'] as String?,
      repairShopName: json['repair_shop_name'] as String?,
      deptName: json['dept_name'] as String?,
      driverName: json['driver_name'] as String?,
      quoteAmount: (json['quote_amount'] ?? 0).toDouble(),
      partsCost: (json['parts_cost'] ?? 0).toDouble(),
      laborCost: (json['labor_cost'] ?? 0).toDouble(),
      hoursCost: (json['hours_cost'] ?? 0).toDouble(),
      partsList: json['parts_list'] as String?,
      quoteDetail: json['quote_detail'] as String?,
      estimatedDays: (json['estimated_days'] ?? 0) as int,
      approvedAt: json['approved_at'] as String?,
      reportDate: json['report_date'] as String?,
    );
  }
}

/// 费用汇总
class CostReportSummary {
  final double totalAmount;
  final double totalParts;
  final double totalLabor;
  final double totalHours;
  final int count;
  final List<ShopSummary> byShop;
  final List<DeptSummary> byDept;

  CostReportSummary({this.totalAmount=0, this.totalParts=0, this.totalLabor=0, this.totalHours=0, this.count=0,
    this.byShop=const [], this.byDept=const []});

  factory CostReportSummary.fromJson(Map<String, dynamic> json) {
    final shops = <ShopSummary>[];
    final byShop = json['byShop'] as Map<String, dynamic>? ?? {};
    for (final e in byShop.entries) {
      final m = e.value as Map<String, dynamic>;
      shops.add(ShopSummary(name: e.key, count: (m['count']??0) as int, totalAmount: (m['totalAmount']??0).toDouble(), totalParts: (m['totalParts']??0).toDouble(), totalLabor: (m['totalLabor']??0).toDouble(), totalHours: (m['totalHours']??0).toDouble()));
    }
    final depts = <DeptSummary>[];
    final byDept = json['byDept'] as Map<String, dynamic>? ?? {};
    for (final e in byDept.entries) {
      final m = e.value as Map<String, dynamic>;
      depts.add(DeptSummary(name: e.key, count: (m['count']??0) as int, totalAmount: (m['totalAmount']??0).toDouble()));
    }
    return CostReportSummary(totalAmount: (json['totalAmount']??0).toDouble(), totalParts: (json['totalParts']??0).toDouble(), totalLabor: (json['totalLabor']??0).toDouble(), totalHours: (json['totalHours']??0).toDouble(), count: (json['count']??0) as int, byShop: shops, byDept: depts);
  }
}

class ShopSummary {
  final String name; final int count; final double totalAmount; final double totalParts; final double totalLabor; final double totalHours;
  ShopSummary({required this.name, this.count=0, this.totalAmount=0, this.totalParts=0, this.totalLabor=0, this.totalHours=0});
}

class DeptSummary {
  final String name; final int count; final double totalAmount;
  DeptSummary({required this.name, this.count=0, this.totalAmount=0});
}

/// 数据库备份
class DbBackup {
  final String name;
  final String size;
  final String mtime;

  DbBackup({required this.name, this.size='', this.mtime=''});

  factory DbBackup.fromJson(Map<String, dynamic> json) {
    return DbBackup(name: (json['name']??'') as String, size: (json['size']??'') as String, mtime: (json['mtime']??'') as String);
  }
}

/// 月度费用统计
class MonthlyCostStat {
  final String month;
  final double totalCost;
  final int orderCount;

  MonthlyCostStat({required this.month, this.totalCost=0, this.orderCount=0});

  factory MonthlyCostStat.fromJson(Map<String, dynamic> json) {
    return MonthlyCostStat(month: (json['month']??'') as String, totalCost: (json['total_cost']??0).toDouble(), orderCount: (json['order_count']??0) as int);
  }
}

/// 每日一测题目（匹配后端 quiz_questions 表）
class QuizQuestion {
  final int id;
  final String question;
  final String type;       // 'choice' | 'truefalse'
  final List<String> options; // 解析自 options JSON 数组
  final String answer;     // 'A'|'B'|'C'|'D' 或 'true'|'false'
  final String explanation;
  final String category;

  QuizQuestion({
    required this.id,
    required this.question,
    this.type = 'choice',
    this.options = const [],
    this.answer = '',
    this.explanation = '',
    this.category = '安全操作',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    List<String> opts = [];
    try {
      final raw = json['options'];
      if (raw is String) {
        opts = (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
      } else if (raw is List) {
        opts = raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return QuizQuestion(
      id: json['id'] as int,
      question: (json['question'] ?? '') as String,
      type: (json['type'] ?? 'choice') as String,
      options: opts,
      answer: (json['answer'] ?? '') as String,
      explanation: (json['explanation'] ?? '') as String,
      category: (json['category'] ?? '安全操作') as String,
    );
  }

  /// A/B/C/D 标签映射
  String get optionLabel {
    switch (answer.toUpperCase()) {
      case 'A': return options.isNotEmpty ? options[0] : '';
      case 'B': return options.length > 1 ? options[1] : '';
      case 'C': return options.length > 2 ? options[2] : '';
      case 'D': return options.length > 3 ? options[3] : '';
      default: return answer;
    }
  }
}

/// 单题答题详情（存在于 quiz_results.answers JSON 中）
class QuizAnswerDetail {
  final int questionId;
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool correct;
  final String explanation;

  QuizAnswerDetail({
    required this.questionId,
    this.question = '',
    this.userAnswer = '',
    this.correctAnswer = '',
    this.correct = false,
    this.explanation = '',
  });

  factory QuizAnswerDetail.fromJson(Map<String, dynamic> json) {
    return QuizAnswerDetail(
      questionId: (json['question_id'] ?? 0) as int,
      question: (json['question'] ?? '') as String,
      userAnswer: (json['user_answer'] ?? '') as String,
      correctAnswer: (json['correct_answer'] ?? '') as String,
      correct: json['correct'] == true || json['correct'] == 1,
      explanation: (json['explanation'] ?? '') as String,
    );
  }
}

/// 答题结果（匹配后端 quiz_results 表 + today API done=true 时返回）
class QuizResult {
  final int id;
  final int score;
  final int total;
  final String quizDate;
  final List<QuizAnswerDetail> answers;

  QuizResult({
    required this.id,
    this.score = 0,
    this.total = 5,
    this.quizDate = '',
    this.answers = const [],
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    List<QuizAnswerDetail> ansList = [];
    try {
      final raw = json['answers'];
      List<dynamic> list;
      if (raw is String) {
        list = jsonDecode(raw) as List<dynamic>;
      } else if (raw is List) {
        list = raw;
      } else {
        list = [];
      }
      ansList = list.map((e) => QuizAnswerDetail.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    return QuizResult(
      id: (json['id'] ?? 0) as int,
      score: (json['score'] ?? 0) as int,
      total: (json['total'] ?? 5) as int,
      quizDate: (json['quiz_date'] ?? '') as String,
      answers: ansList,
    );
  }
}

/// 答题排行榜条目（匹配后端 leaderboard API）
class QuizLeaderboardEntry {
  final int userId;
  final String name;
  final int totalScore;
  final int days;
  final int likes;
  final bool likedByMe;

  QuizLeaderboardEntry({
    required this.userId,
    this.name = '',
    this.totalScore = 0,
    this.days = 0,
    this.likes = 0,
    this.likedByMe = false,
  });

  factory QuizLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return QuizLeaderboardEntry(
      userId: (json['user_id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      totalScore: (json['total_score'] ?? 0) as int,
      days: (json['days'] ?? 0) as int,
      likes: (json['likes'] ?? 0) as int,
      likedByMe: json['liked_by_me'] == true || json['liked_by_me'] == 1,
    );
  }
}


/// 工单导出条目
class ExportOrder {
  final String orderNo;
  final String plateNumber;
  final String? vehicleType;
  final String? driverName;
  final String? deptName;
  final String? repairShopName;
  final String? faultDescription;
  final String status;
  final String? reportDate;
  final double quoteAmount;
  final double partsCost;
  final double laborCost;
  final double hoursCost;
  final String? acceptDate;
  final String? quoteDate;
  final String? repairStartDate;
  final String? completeDate;
  final String? acceptVehicleDate;

  ExportOrder({required this.orderNo, this.plateNumber='', this.vehicleType, this.driverName, this.deptName, this.repairShopName, this.faultDescription, required this.status, this.reportDate, this.quoteAmount=0, this.partsCost=0, this.laborCost=0, this.hoursCost=0, this.acceptDate, this.quoteDate, this.repairStartDate, this.completeDate, this.acceptVehicleDate});

  factory ExportOrder.fromJson(Map<String, dynamic> json) {
    return ExportOrder(
      orderNo: (json['order_no']??'') as String, plateNumber: (json['plate_number']??'') as String,
      vehicleType: json['vehicle_type'] as String?, driverName: json['driver_name'] as String?,
      deptName: json['dept_name'] as String?, repairShopName: json['repair_shop_name'] as String?,
      faultDescription: json['fault_description'] as String?, status: (json['status']??'') as String,
      reportDate: json['report_date'] as String?, quoteAmount: (json['quote_amount']??0).toDouble(),
      partsCost: (json['parts_cost']??0).toDouble(), laborCost: (json['labor_cost']??0).toDouble(),
      hoursCost: (json['hours_cost']??0).toDouble(), acceptDate: json['accept_date'] as String?,
      quoteDate: json['quote_date'] as String?, repairStartDate: json['repair_start_date'] as String?,
      completeDate: json['complete_date'] as String?, acceptVehicleDate: json['accept_vehicle_date'] as String?,
    );
  }

  String get statusLabel => RepairStatusStat._statusLabels[status] ?? status;
}
