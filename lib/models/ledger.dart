/// 月度单车核算清单
class MonthlyLedger {
  final int id;
  final int vehicleId;
  final String yearMonth;
  final double fuelCost;
  final double repairCost;
  final double partsCost;
  final int workDays;
  final double totalHours;
  final double hourlyFuelConsumption;
  final double totalCost;
  final double revenue;
  final double profit;
  final String status; // draft | submitted | approved
  final int? submittedBy;
  final int? approvedBy;
  final String? plateNumber;
  final String? vehicleType;
  final String createdAt;
  final String updatedAt;

  MonthlyLedger({
    required this.id,
    required this.vehicleId,
    required this.yearMonth,
    this.fuelCost = 0,
    this.repairCost = 0,
    this.partsCost = 0,
    this.workDays = 0,
    this.totalHours = 0,
    this.hourlyFuelConsumption = 0,
    this.totalCost = 0,
    this.revenue = 0,
    this.profit = 0,
    this.status = 'draft',
    this.submittedBy,
    this.approvedBy,
    this.plateNumber,
    this.vehicleType,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory MonthlyLedger.fromJson(Map<String, dynamic> json) {
    return MonthlyLedger(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      yearMonth: (json['year_month'] ?? '') as String,
      fuelCost: (json['fuel_cost'] ?? 0).toDouble(),
      repairCost: (json['repair_cost'] ?? 0).toDouble(),
      partsCost: (json['parts_cost'] ?? 0).toDouble(),
      workDays: (json['work_days'] ?? 0) as int,
      totalHours: (json['total_hours'] ?? 0).toDouble(),
      hourlyFuelConsumption: (json['hourly_fuel_consumption'] ?? 0).toDouble(),
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      revenue: (json['revenue'] ?? 0).toDouble(),
      profit: (json['profit'] ?? 0).toDouble(),
      status: (json['status'] ?? 'draft') as String,
      submittedBy: json['submitted_by'] as int?,
      approvedBy: json['approved_by'] as int?,
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  String get vehicleDisplay => plateNumber != null && vehicleType != null
      ? '$plateNumber ($vehicleType)'
      : plateNumber ?? '未知车辆';

  String get statusLabel {
    switch (status) {
      case 'draft': return '草稿';
      case 'submitted': return '待审批';
      case 'approved': return '已审批';
      default: return status;
    }
  }

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isApproved => status == 'approved';

  /// 盈亏符号
  String get profitDisplay => profit >= 0 ? '+¥${profit.toStringAsFixed(2)}' : '-¥${(-profit).toStringAsFixed(2)}';
}

/// KPI考核评分
class KpiScore {
  final int id;
  final int vehicleId;
  final String yearMonth;
  final double fuelCostPerUnit;
  final double repairRate;
  final double utilizationRate;
  final double unitCost;
  final double availabilityRate;
  final double safetyScore;
  final double totalScore;
  final int rank;
  final String? plateNumber;
  final String? vehicleType;
  final String? model;

  // 关联的月度清单数据
  final double fuelCost;
  final double repairCost;
  final double partsCost;
  final double totalCost;
  final int workDays;
  final double totalHours;

  // 奖惩
  final List<KpiPenaltyReward> penalties;
  final List<KpiPenaltyReward> rewards;
  final double totalPenalty;
  final double totalReward;

  KpiScore({
    required this.id,
    required this.vehicleId,
    required this.yearMonth,
    this.fuelCostPerUnit = 0,
    this.repairRate = 0,
    this.utilizationRate = 0,
    this.unitCost = 0,
    this.availabilityRate = 0,
    this.safetyScore = 0,
    this.totalScore = 0,
    this.rank = 0,
    this.plateNumber,
    this.vehicleType,
    this.model,
    this.fuelCost = 0,
    this.repairCost = 0,
    this.partsCost = 0,
    this.totalCost = 0,
    this.workDays = 0,
    this.totalHours = 0,
    this.penalties = const [],
    this.rewards = const [],
    this.totalPenalty = 0,
    this.totalReward = 0,
  });

  factory KpiScore.fromJson(Map<String, dynamic> json) {
    final penalties = (json['penalties'] as List<dynamic>? ?? [])
        .map((v) => KpiPenaltyReward.fromJson(v as Map<String, dynamic>))
        .toList();
    final rewards = (json['rewards'] as List<dynamic>? ?? [])
        .map((v) => KpiPenaltyReward.fromJson(v as Map<String, dynamic>))
        .toList();

    return KpiScore(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      yearMonth: (json['year_month'] ?? '') as String,
      fuelCostPerUnit: (json['fuel_cost_per_unit'] ?? 0).toDouble(),
      repairRate: (json['repair_rate'] ?? 0).toDouble(),
      utilizationRate: (json['utilization_rate'] ?? 0).toDouble(),
      unitCost: (json['unit_cost'] ?? 0).toDouble(),
      availabilityRate: (json['availability_rate'] ?? 0).toDouble(),
      safetyScore: (json['safety_score'] ?? 0).toDouble(),
      totalScore: (json['total_score'] ?? 0).toDouble(),
      rank: (json['rank'] ?? 0) as int,
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      model: json['model'] as String?,
      fuelCost: (json['fuel_cost'] ?? 0).toDouble(),
      repairCost: (json['repair_cost'] ?? 0).toDouble(),
      partsCost: (json['parts_cost'] ?? 0).toDouble(),
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      workDays: (json['work_days'] ?? 0) as int,
      totalHours: (json['total_hours'] ?? 0).toDouble(),
      penalties: penalties,
      rewards: rewards,
      totalPenalty: (json['total_penalty'] ?? 0).toDouble(),
      totalReward: (json['total_reward'] ?? 0).toDouble(),
    );
  }

  String get vehicleDisplay => plateNumber != null && vehicleType != null
      ? '$plateNumber ($vehicleType)'
      : plateNumber ?? '未知车辆';

  String get rankDisplay {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$rank';
    }
  }

  bool get hasPenalty => totalPenalty > 0;
  bool get hasReward => totalReward > 0;
}

/// KPI奖惩项
class KpiPenaltyReward {
  final String kpi;
  final double value;
  final double threshold;
  final double amount;
  final String reason;

  KpiPenaltyReward({
    required this.kpi,
    required this.value,
    required this.threshold,
    required this.amount,
    required this.reason,
  });

  factory KpiPenaltyReward.fromJson(Map<String, dynamic> json) {
    return KpiPenaltyReward(
      kpi: (json['kpi'] ?? '') as String,
      value: (json['value'] ?? 0).toDouble(),
      threshold: (json['threshold'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
      reason: (json['reason'] ?? '') as String,
    );
  }

  String get kpiLabel => _kpiLabels[kpi] ?? kpi;

  static const Map<String, String> _kpiLabels = {
    'fuel_cost_per_unit': '燃油成本',
    'repair_rate': '维修费率',
    'utilization_rate': '利用率',
    'unit_cost': '单位成本',
    'availability_rate': '完好率',
    'safety_score': '安全得分',
  };
}

/// KPI阈值配置
class KpiThreshold {
  final String vehicleType;
  final String kpiKey;
  final double upperLimit;
  final double lowerLimit;
  final double penaltyAmount;
  final double rewardAmount;
  final String updatedAt;

  KpiThreshold({
    required this.vehicleType,
    required this.kpiKey,
    this.upperLimit = 0,
    this.lowerLimit = 0,
    this.penaltyAmount = 0,
    this.rewardAmount = 0,
    this.updatedAt = '',
  });

  factory KpiThreshold.fromJson(Map<String, dynamic> json) {
    return KpiThreshold(
      vehicleType: (json['vehicle_type'] ?? '') as String,
      kpiKey: (json['kpi_key'] ?? '') as String,
      upperLimit: (json['upper_limit'] ?? 0).toDouble(),
      lowerLimit: (json['lower_limit'] ?? 0).toDouble(),
      penaltyAmount: (json['penalty_amount'] ?? 0).toDouble(),
      rewardAmount: (json['reward_amount'] ?? 0).toDouble(),
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_type': vehicleType,
    'kpi_key': kpiKey,
    'upper_limit': upperLimit,
    'lower_limit': lowerLimit,
    'penalty_amount': penaltyAmount,
    'reward_amount': rewardAmount,
  };

  String get kpiLabel => KpiPenaltyReward._kpiLabels[kpiKey] ?? kpiKey;
  String get kpiDesc => _kpiDescs[kpiKey] ?? '';

  static const Map<String, String> _kpiDescs = {
    'fuel_cost_per_unit': '月燃油费÷出勤天数（元/天），越低越好',
    'repair_rate': '月维修费÷车辆资产净值（%），越低越好',
    'utilization_rate': '出勤天数÷26天制度台班（%），越高越好',
    'unit_cost': '月总成本÷月总工时（元/h），越低越好',
    'availability_rate': '(26天−维修天数)÷26天（%），越高越好',
    'safety_score': '100−事故次数×10，越高越好',
  };
}

/// 台账汇总仪表盘数据
class LedgerSummary {
  final String month;
  final double fuelCost;
  final double partsCost;
  final double repairCost;
  final double totalCost;
  final double totalRevenue;
  final double totalProfit;
  final int approvedLedgers;
  final bool hasKpi;

  LedgerSummary({
    required this.month,
    this.fuelCost = 0,
    this.partsCost = 0,
    this.repairCost = 0,
    this.totalCost = 0,
    this.totalRevenue = 0,
    this.totalProfit = 0,
    this.approvedLedgers = 0,
    this.hasKpi = false,
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    return LedgerSummary(
      month: (json['month'] ?? '') as String,
      fuelCost: (json['fuelCost'] ?? 0).toDouble(),
      partsCost: (json['partsCost'] ?? 0).toDouble(),
      repairCost: (json['repairCost'] ?? 0).toDouble(),
      totalCost: (json['totalCost'] ?? 0).toDouble(),
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalProfit: (json['totalProfit'] ?? 0).toDouble(),
      approvedLedgers: (json['approvedLedgers'] ?? 0) as int,
      hasKpi: json['hasKpi'] == true || json['hasKpi'] == 1,
    );
  }

  String get profitDisplay => totalProfit >= 0 ? '+¥${totalProfit.toStringAsFixed(2)}' : '-¥${(-totalProfit).toStringAsFixed(2)}';
}

// ==================== 趋势对比 ====================

/// 单个趋势月份数据
class TrendMonthData {
  final String yearMonth;
  final double fuelCost;
  final double repairCost;
  final double partsCost;
  final double totalCost;
  final double hourlyFuelConsumption;
  final int workDays;
  final double totalHours;
  final double revenue;
  final double profit;
  final String status;

  // 环比变化 (首月为null)
  final double? fuelCostChange;
  final double? fuelCostChangePct;
  final double? repairCostChange;
  final double? repairCostChangePct;
  final double? partsCostChange;
  final double? partsCostChangePct;
  final double? totalCostChange;
  final double? totalCostChangePct;
  final double? profitChange;
  final double? profitChangePct;
  final int repairRisingConsecutive;

  TrendMonthData({
    required this.yearMonth,
    this.fuelCost = 0, this.repairCost = 0, this.partsCost = 0,
    this.totalCost = 0, this.hourlyFuelConsumption = 0,
    this.workDays = 0, this.totalHours = 0, this.revenue = 0, this.profit = 0,
    this.status = 'draft',
    this.fuelCostChange, this.fuelCostChangePct,
    this.repairCostChange, this.repairCostChangePct,
    this.partsCostChange, this.partsCostChangePct,
    this.totalCostChange, this.totalCostChangePct,
    this.profitChange, this.profitChangePct,
    this.repairRisingConsecutive = 0,
  });

  factory TrendMonthData.fromJson(Map<String, dynamic> json) {
    return TrendMonthData(
      yearMonth: (json['year_month'] ?? '') as String,
      fuelCost: (json['fuel_cost'] ?? 0).toDouble(),
      repairCost: (json['repair_cost'] ?? 0).toDouble(),
      partsCost: (json['parts_cost'] ?? 0).toDouble(),
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      hourlyFuelConsumption: (json['hourly_fuel_consumption'] ?? 0).toDouble(),
      workDays: (json['work_days'] ?? 0) as int,
      totalHours: (json['total_hours'] ?? 0).toDouble(),
      revenue: (json['revenue'] ?? 0).toDouble(),
      profit: (json['profit'] ?? 0).toDouble(),
      status: (json['status'] ?? 'draft') as String,
      fuelCostChange: (json['fuel_cost_change'] as num?)?.toDouble(),
      fuelCostChangePct: (json['fuel_cost_change_pct'] as num?)?.toDouble(),
      repairCostChange: (json['repair_cost_change'] as num?)?.toDouble(),
      repairCostChangePct: (json['repair_cost_change_pct'] as num?)?.toDouble(),
      partsCostChange: (json['parts_cost_change'] as num?)?.toDouble(),
      partsCostChangePct: (json['parts_cost_change_pct'] as num?)?.toDouble(),
      totalCostChange: (json['total_cost_change'] as num?)?.toDouble(),
      totalCostChangePct: (json['total_cost_change_pct'] as num?)?.toDouble(),
      profitChange: (json['profit_change'] as num?)?.toDouble(),
      profitChangePct: (json['profit_change_pct'] as num?)?.toDouble(),
      repairRisingConsecutive: (json['repair_rising_consecutive'] ?? 0) as int,
    );
  }

  bool get isRepairRising => repairCostChange != null && repairCostChange! > 0;
  bool get isRepairDropping => repairCostChange != null && repairCostChange! < 0;
  bool get hasRisingAlert => repairRisingConsecutive >= 2;

  String get monthLabel {
    final parts = yearMonth.split('-');
    return parts.length == 2 ? '${parts[1]}月' : yearMonth;
  }
}

/// 车辆趋势预警汇总
class VehicleTrendAlerts {
  final bool hasRisingAlert;
  final int maxRepairRisingConsecutive;
  final double avgHourlyFuelConsumption;
  final double avgMonthlyRepairCost;
  final double totalRepairCost;

  VehicleTrendAlerts({
    this.hasRisingAlert = false,
    this.maxRepairRisingConsecutive = 0,
    this.avgHourlyFuelConsumption = 0,
    this.avgMonthlyRepairCost = 0,
    this.totalRepairCost = 0,
  });

  factory VehicleTrendAlerts.fromJson(Map<String, dynamic> json) {
    return VehicleTrendAlerts(
      hasRisingAlert: json['has_rising_alert'] == true,
      maxRepairRisingConsecutive: (json['max_repair_rising_consecutive'] ?? 0) as int,
      avgHourlyFuelConsumption: (json['avg_hourly_fuel_consumption'] ?? 0).toDouble(),
      avgMonthlyRepairCost: (json['avg_monthly_repair_cost'] ?? 0).toDouble(),
      totalRepairCost: (json['total_repair_cost'] ?? 0).toDouble(),
    );
  }
}

/// 一辆车的完整趋势数据
class VehicleTrend {
  final int vehicleId;
  final String plateNumber;
  final String vehicleType;
  final String model;
  final VehicleTrendAlerts alerts;
  final List<TrendMonthData> data;

  VehicleTrend({
    required this.vehicleId,
    this.plateNumber = '', this.vehicleType = '', this.model = '',
    required this.alerts, required this.data,
  });

  factory VehicleTrend.fromJson(Map<String, dynamic> json) {
    return VehicleTrend(
      vehicleId: (json['vehicle_id'] ?? 0) as int,
      plateNumber: (json['plate_number'] ?? '') as String,
      vehicleType: (json['vehicle_type'] ?? '') as String,
      model: (json['model'] ?? '') as String,
      alerts: VehicleTrendAlerts.fromJson((json['alerts'] as Map<String, dynamic>?) ?? {}),
      data: ((json['data'] as List<dynamic>?) ?? [])
          .map((v) => TrendMonthData.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  String get vehicleDisplay => '$plateNumber ($vehicleType)';
  int get monthCount => data.length;
  bool get hasSufficientData => data.length >= 2;
}
