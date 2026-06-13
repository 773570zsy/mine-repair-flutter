import '../models/ledger.dart';
import '../models/budget.dart';
import 'http_client.dart';

class LedgerService {
  final HttpClient _client = HttpClient();

  // ==================== 月度单车核算清单 ====================

  /// 查询月度清单
  Future<List<MonthlyLedger>> getMonthlyLedgers({
    String? yearMonth,
    int? vehicleId,
    String? status,
  }) async {
    final resp = await _client.get('/ledger/monthly', queryParams: {
      if (yearMonth != null) 'year_month': yearMonth,
      if (vehicleId != null) 'vehicle_id': vehicleId.toString(),
      if (status != null) 'status': status,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取月度清单失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MonthlyLedger.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 可用年月列表
  Future<List<String>> getMonthOptions() async {
    final resp = await _client.get('/ledger/monthly/months');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取年月列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => v.toString()).toList();
  }

  // ==================== 年度汇总 ====================

  /// 年度单车核算汇总
  Future<List<Map<String, dynamic>>> getAnnualLedger(String year) async {
    final resp = await _client.get('/ledger/annual', queryParams: {'year': year});
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取年度汇总失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => v as Map<String, dynamic>).toList();
  }

  // ==================== 趋势对比 ====================

  /// 获取车辆月度趋势数据（环比变化 + 连续上涨检测）
  Future<List<VehicleTrend>> getVehicleTrend({required String year, int? vehicleId}) async {
    final params = <String, dynamic>{'year': year};
    if (vehicleId != null) params['vehicle_id'] = vehicleId.toString();
    final resp = await _client.get('/ledger/trend', queryParams: params);
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取趋势数据失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => VehicleTrend.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 生成月度清单
  Future<({String msg, List<Map<String, dynamic>> data})> generateMonthlyLedger(String yearMonth) async {
    final resp = await _client.post('/ledger/monthly/generate', data: {
      'year_month': yearMonth,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '生成失败');
    final data = (resp.data as List<dynamic>? ?? []).map((v) => v as Map<String, dynamic>).toList();
    return (msg: resp.msg ?? '生成成功', data: data);
  }

  /// 提交月度清单
  Future<String> submitMonthlyLedger(int id) async {
    final resp = await _client.put('/ledger/monthly/$id/submit');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '提交失败');
    return resp.msg ?? '已提交';
  }

  /// 审批月度清单
  Future<String> approveMonthlyLedger(int id) async {
    final resp = await _client.put('/ledger/monthly/$id/approve');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '审批失败');
    return resp.msg ?? '审批通过';
  }

  // ==================== KPI考核评分 ====================

  /// 查询KPI评分
  Future<List<KpiScore>> getKpiScores({String? yearMonth}) async {
    final resp = await _client.get('/ledger/kpi', queryParams: {
      if (yearMonth != null) 'year_month': yearMonth,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取KPI失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => KpiScore.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 自动计算KPI
  Future<({String msg, List<KpiScore> scores})> calculateKpi(String yearMonth) async {
    final resp = await _client.post('/ledger/kpi/calculate', data: {
      'year_month': yearMonth,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '计算失败');
    final list = (resp.data as List<dynamic>? ?? [])
        .map((v) => KpiScore.fromJson(v as Map<String, dynamic>))
        .toList();
    return (msg: resp.msg ?? '计算完成', scores: list);
  }

  // ==================== KPI阈值配置 ====================

  /// 查看阈值配置
  Future<({List<KpiThreshold> items, Map<String, List<KpiThreshold>> grouped})> getThresholds() async {
    final resp = await _client.get('/ledger/thresholds');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取阈值失败');
    final data = resp.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((v) => KpiThreshold.fromJson(v as Map<String, dynamic>))
        .toList();
    final groupedRaw = data['grouped'] as Map<String, dynamic>? ?? {};
    final grouped = <String, List<KpiThreshold>>{};
    for (final entry in groupedRaw.entries) {
      grouped[entry.key] = (entry.value as List<dynamic>)
          .map((v) => KpiThreshold.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    return (items: items, grouped: grouped);
  }

  /// 保存阈值配置
  Future<String> saveThresholds(List<KpiThreshold> thresholds) async {
    final resp = await _client.put('/ledger/thresholds/save', data: {
      'thresholds': thresholds.map((t) => t.toJson()).toList(),
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '保存失败');
    return resp.msg ?? '保存成功';
  }

  // ==================== 汇总 ====================

  /// 台账汇总（仪表盘用）
  Future<LedgerSummary> getSummary({String? month}) async {
    final resp = await _client.get('/ledger/summary', queryParams: {
      if (month != null) 'month': month,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取汇总失败');
    return LedgerSummary.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 导出月度清单CSV（返回原始CSV文本）
  Future<String> exportMonthlyCsv({String? yearMonth}) async {
    return await _client.getText('/ledger/monthly/export', queryParams: {
      if (yearMonth != null) 'year_month': yearMonth,
    });
  }

  /// 导出年度汇总CSV（返回原始CSV文本）
  Future<String> exportAnnualCsv({required String year}) async {
    return await _client.getText('/ledger/annual/export', queryParams: {'year': year});
  }

  // ==================== 维修预算 ====================

  /// 车型预算配置列表
  Future<List<BudgetVehicleConfig>> getBudgetConfigs() async {
    final resp = await _client.get('/ledger/budget/config');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取预算配置失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => BudgetVehicleConfig.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 保存车型预算配置
  Future<String> saveBudgetConfigs(List<BudgetVehicleConfig> configs) async {
    final resp = await _client.put('/ledger/budget/config', data: {
      'configs': configs.map((c) => c.toJson()).toList(),
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '保存失败');
    return resp.msg ?? '保存成功';
  }

  /// 导入基准数据
  Future<String> importBaselines(String baseYear, List<Map<String, dynamic>> records) async {
    final resp = await _client.post('/ledger/budget/import', data: {
      'base_year': baseYear,
      'records': records,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '导入失败');
    return resp.msg ?? '导入完成';
  }

  /// 查询基准数据
  Future<List<BudgetBaseline>> getBaselines({String? baseYear}) async {
    final resp = await _client.get('/ledger/budget/baselines', queryParams: {
      if (baseYear != null) 'base_year': baseYear,
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取基准数据失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => BudgetBaseline.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 计算月度预算
  Future<List<MonthlyBudget>> calculateBudget(String yearMonth) async {
    final resp = await _client.post('/ledger/budget/calculate/$yearMonth');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '计算失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MonthlyBudget.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 查询月度预算列表
  Future<MonthlyBudgetSummary> getMonthlyBudget(String yearMonth) async {
    final resp = await _client.get('/ledger/budget/list/$yearMonth');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取预算列表失败');
    return MonthlyBudgetSummary.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 年度预算汇总
  Future<List<YearlyBudgetSummary>> getYearlyBudgetSummary(String year) async {
    final resp = await _client.get('/ledger/budget/summary/$year');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取年度汇总失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => YearlyBudgetSummary.fromJson(v as Map<String, dynamic>)).toList();
  }
}
