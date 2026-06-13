/// 车型预算增幅配置
class BudgetVehicleConfig {
  final String vehicleType;
  final double annualIncreaseRate;
  final String updatedAt;

  BudgetVehicleConfig({
    required this.vehicleType,
    this.annualIncreaseRate = 0.05,
    this.updatedAt = '',
  });

  factory BudgetVehicleConfig.fromJson(Map<String, dynamic> json) {
    return BudgetVehicleConfig(
      vehicleType: (json['vehicle_type'] ?? '') as String,
      annualIncreaseRate: (json['annual_increase_rate'] ?? 0.05).toDouble(),
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_type': vehicleType,
    'annual_increase_rate': annualIncreaseRate,
  };

  String get ratePercent => '${(annualIncreaseRate * 100).toStringAsFixed(1)}%';
}

/// 基准预算数据（导入的年度汇总）
class BudgetBaseline {
  final int id;
  final int vehicleId;
  final String baseYear;
  final double totalAnnualCost;
  final String? plateNumber;
  final String? vehicleType;
  final String? purchaseDate;
  final double? assetValue;

  BudgetBaseline({
    required this.id,
    required this.vehicleId,
    required this.baseYear,
    this.totalAnnualCost = 0,
    this.plateNumber,
    this.vehicleType,
    this.purchaseDate,
    this.assetValue,
  });

  factory BudgetBaseline.fromJson(Map<String, dynamic> json) {
    return BudgetBaseline(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      baseYear: (json['base_year'] ?? '') as String,
      totalAnnualCost: (json['total_annual_cost'] ?? 0).toDouble(),
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      purchaseDate: json['purchase_date'] as String?,
      assetValue: (json['asset_value'] as num?)?.toDouble(),
    );
  }

  double get baseMonthly => totalAnnualCost / 12;

  String get vehicleDisplay => plateNumber != null && vehicleType != null
      ? '$plateNumber ($vehicleType)'
      : plateNumber ?? '未知车辆';
}

/// 单车月度预算
class MonthlyBudget {
  final int id;
  final int vehicleId;
  final String yearMonth;
  final double budgetAmount;
  final double actualAmount;
  final double variance;
  final String? plateNumber;
  final String? vehicleType;

  // 计算明细（来自 calculate 接口）
  final String? baseYear;
  final double? totalAnnualCost;
  final double? baseMonthly;
  final int? purchaseYear;
  final int? vehicleAge;
  final double? annualIncreaseRate;
  final String? status; // over / under / on_budget

  MonthlyBudget({
    required this.id,
    required this.vehicleId,
    required this.yearMonth,
    this.budgetAmount = 0,
    this.actualAmount = 0,
    this.variance = 0,
    this.plateNumber,
    this.vehicleType,
    this.baseYear,
    this.totalAnnualCost,
    this.baseMonthly,
    this.purchaseYear,
    this.vehicleAge,
    this.annualIncreaseRate,
    this.status,
  });

  factory MonthlyBudget.fromJson(Map<String, dynamic> json) {
    return MonthlyBudget(
      id: (json['id'] ?? 0) as int,
      vehicleId: json['vehicle_id'] as int,
      yearMonth: (json['year_month'] ?? '') as String,
      budgetAmount: (json['budget_amount'] ?? 0).toDouble(),
      actualAmount: (json['actual_amount'] ?? 0).toDouble(),
      variance: (json['variance'] ?? 0).toDouble(),
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      baseYear: json['base_year'] as String?,
      totalAnnualCost: (json['total_annual_cost'] as num?)?.toDouble(),
      baseMonthly: (json['base_monthly'] as num?)?.toDouble(),
      purchaseYear: json['purchase_year'] as int?,
      vehicleAge: json['vehicle_age'] as int?,
      annualIncreaseRate: (json['annual_increase_rate'] as num?)?.toDouble(),
      status: json['status'] as String?,
    );
  }

  String get vehicleDisplay => plateNumber != null && vehicleType != null
      ? '$plateNumber ($vehicleType)'
      : plateNumber ?? '未知车辆';

  bool get isOver => variance > 0;
  bool get isUnder => variance < 0;
  bool get isOnBudget => variance == 0;

  String get varianceDisplay => variance >= 0 ? '+¥${variance.toStringAsFixed(2)}' : '-¥${(-variance).toStringAsFixed(2)}';
}

/// 月度预算汇总（列表接口返回）
class MonthlyBudgetSummary {
  final String yearMonth;
  final double totalBudget;
  final double totalActual;
  final double totalVariance;
  final List<MonthlyBudget> items;

  MonthlyBudgetSummary({
    required this.yearMonth,
    this.totalBudget = 0,
    this.totalActual = 0,
    this.totalVariance = 0,
    this.items = const [],
  });

  factory MonthlyBudgetSummary.fromJson(Map<String, dynamic> json) {
    return MonthlyBudgetSummary(
      yearMonth: (json['year_month'] ?? '') as String,
      totalBudget: (json['total_budget'] ?? 0).toDouble(),
      totalActual: (json['total_actual'] ?? 0).toDouble(),
      totalVariance: (json['total_variance'] ?? 0).toDouble(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((v) => MonthlyBudget.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isOverBudget => totalVariance > 0;
  String get varianceDisplay => totalVariance >= 0 ? '+¥${totalVariance.toStringAsFixed(2)}' : '-¥${(-totalVariance).toStringAsFixed(2)}';
}

/// 年度预算汇总
class YearlyBudgetSummary {
  final String yearMonth;
  final double totalBudget;
  final double totalActual;
  final double totalVariance;
  final int vehicleCount;

  YearlyBudgetSummary({
    required this.yearMonth,
    this.totalBudget = 0,
    this.totalActual = 0,
    this.totalVariance = 0,
    this.vehicleCount = 0,
  });

  factory YearlyBudgetSummary.fromJson(Map<String, dynamic> json) {
    return YearlyBudgetSummary(
      yearMonth: (json['year_month'] ?? '') as String,
      totalBudget: (json['total_budget'] ?? 0).toDouble(),
      totalActual: (json['total_actual'] ?? 0).toDouble(),
      totalVariance: (json['total_variance'] ?? 0).toDouble(),
      vehicleCount: (json['vehicle_count'] ?? 0) as int,
    );
  }
}
