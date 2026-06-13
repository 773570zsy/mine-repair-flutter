import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ledger.dart';
import '../models/budget.dart';
import '../services/ledger_service.dart';

/// Service singleton
final ledgerServiceProvider = Provider<LedgerService>((ref) => LedgerService());

// ==================== 汇总（仪表盘） ====================

/// 台账仪表盘汇总
final ledgerSummaryProvider = FutureProvider.family<LedgerSummary, String?>((ref, month) {
  return ref.read(ledgerServiceProvider).getSummary(month: month);
});

// ==================== 月度清单 ====================

/// 月度清单列表
final monthlyLedgersProvider = FutureProvider.family<List<MonthlyLedger>, MonthlyFilter>((ref, filter) {
  return ref.read(ledgerServiceProvider).getMonthlyLedgers(
    yearMonth: filter.yearMonth,
    vehicleId: filter.vehicleId,
    status: filter.status,
  );
});

class MonthlyFilter {
  final String? yearMonth;
  final int? vehicleId;
  final String? status;

  MonthlyFilter({this.yearMonth, this.vehicleId, this.status});

  @override
  bool operator ==(Object other) =>
      other is MonthlyFilter &&
      other.yearMonth == yearMonth &&
      other.vehicleId == vehicleId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(yearMonth, vehicleId, status);
}

/// 可用年月列表
final monthOptionsProvider = FutureProvider<List<String>>((ref) {
  return ref.read(ledgerServiceProvider).getMonthOptions();
});

// ==================== 年度汇总 ====================

/// 年度单车核算汇总
final annualLedgerProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, year) {
  return ref.read(ledgerServiceProvider).getAnnualLedger(year);
});

// ==================== 趋势对比 ====================

/// 趋势筛选条件
class TrendFilter {
  final String year;
  final int? vehicleId;

  const TrendFilter({required this.year, this.vehicleId});

  @override
  bool operator ==(Object other) =>
      other is TrendFilter && other.year == year && other.vehicleId == vehicleId;

  @override
  int get hashCode => Object.hash(year, vehicleId);
}

/// 车辆月度趋势数据
final vehicleTrendProvider = FutureProvider.family<List<VehicleTrend>, TrendFilter>((ref, filter) {
  return ref.read(ledgerServiceProvider).getVehicleTrend(
    year: filter.year,
    vehicleId: filter.vehicleId,
  );
});

// ==================== KPI ====================

/// KPI评分列表
final kpiScoresProvider = FutureProvider.family<List<KpiScore>, String?>((ref, yearMonth) {
  return ref.read(ledgerServiceProvider).getKpiScores(yearMonth: yearMonth);
});

// ==================== 阈值 ====================

/// 阈值配置
final thresholdsProvider = FutureProvider<({List<KpiThreshold> items, Map<String, List<KpiThreshold>> grouped})>((ref) {
  return ref.read(ledgerServiceProvider).getThresholds();
});

// ==================== 预算 ====================

/// 车型预算配置列表
final budgetConfigsProvider = FutureProvider<List<BudgetVehicleConfig>>((ref) {
  return ref.read(ledgerServiceProvider).getBudgetConfigs();
});

/// 基准数据列表
final budgetBaselinesProvider = FutureProvider.family<List<BudgetBaseline>, String?>((ref, baseYear) {
  return ref.read(ledgerServiceProvider).getBaselines(baseYear: baseYear);
});

/// 月度预算列表
final monthlyBudgetProvider = FutureProvider.family<MonthlyBudgetSummary, String>((ref, yearMonth) {
  return ref.read(ledgerServiceProvider).getMonthlyBudget(yearMonth);
});

/// 年度预算汇总
final yearlyBudgetSummaryProvider = FutureProvider.family<List<YearlyBudgetSummary>, String>((ref, year) {
  return ref.read(ledgerServiceProvider).getYearlyBudgetSummary(year);
});

// ==================== 操作 ====================

class LedgerActions {
  final LedgerService _service;

  LedgerActions(this._service);

  // --- 月度清单 ---
  Future<({String msg, List<Map<String, dynamic>> data})> generateMonthlyLedger(String yearMonth) async {
    return _service.generateMonthlyLedger(yearMonth);
  }

  Future<String> submitMonthlyLedger(int id) async {
    return _service.submitMonthlyLedger(id);
  }

  Future<String> approveMonthlyLedger(int id) async {
    return _service.approveMonthlyLedger(id);
  }

  // --- KPI ---
  Future<({String msg, List<KpiScore> scores})> calculateKpi(String yearMonth) async {
    return _service.calculateKpi(yearMonth);
  }

  // --- 阈值 ---
  Future<String> saveThresholds(List<KpiThreshold> thresholds) async {
    return _service.saveThresholds(thresholds);
  }

  // --- 预算 ---
  Future<String> saveBudgetConfigs(List<BudgetVehicleConfig> configs) async {
    return _service.saveBudgetConfigs(configs);
  }

  Future<String> importBaselines(String baseYear, List<Map<String, dynamic>> records) async {
    return _service.importBaselines(baseYear, records);
  }

  Future<List<MonthlyBudget>> calculateBudget(String yearMonth) async {
    return _service.calculateBudget(yearMonth);
  }
}

final ledgerActionsProvider = Provider<LedgerActions>((ref) {
  final service = ref.read(ledgerServiceProvider);
  return LedgerActions(service);
});
