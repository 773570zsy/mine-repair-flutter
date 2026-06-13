import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ledger_provider.dart';
import '../../models/ledger.dart';
import 'components/simple_bar_chart.dart';

import '../../config/color_constants.dart';
import '../../utils/export_helper.dart';

class MonthlyLedgerPage extends ConsumerStatefulWidget {
  const MonthlyLedgerPage({super.key});

  @override
  ConsumerState<MonthlyLedgerPage> createState() => _MonthlyLedgerPageState();
}

class _MonthlyLedgerPageState extends ConsumerState<MonthlyLedgerPage> {
  String _selMonth = '';
  String? _selStatus;
  bool _isAnnual = false;
  bool _isTrend = false;
  String _selYear = '';
  int? _selTrendVehicleId; // null = 全部车辆

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _selYear = '${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final actions = ref.read(ledgerActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isTrend ? '月度趋势对比' : (_isAnnual ? '年度单车核算汇总' : '月度单车核算清单')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              _toggleChip('月度', !_isAnnual && !_isTrend, () => setState(() { _isAnnual = false; _isTrend = false; _selTrendVehicleId = null; })),
              const SizedBox(width: 6),
              _toggleChip('年度', _isAnnual, () => setState(() { _isAnnual = true; _isTrend = false; _selTrendVehicleId = null; })),
              const SizedBox(width: 6),
              _toggleChip('趋势', _isTrend, () => setState(() { _isAnnual = false; _isTrend = true; })),
            ]),
          ),
        ),
      ),
      body: _isTrend ? _trendBody() : (_isAnnual ? _annualBody() : _monthlyBody(actions)),
    );
  }

  // ==================== 切换按钮 ====================

  Widget _toggleChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surface2,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          color: active ? AppColors.bg : AppColors.text2,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }

  // ==================== 月度视图 ====================

  Widget _monthlyBody(dynamic actions) {
    final filter = MonthlyFilter(yearMonth: _selMonth, status: _selStatus);
    final async = ref.watch(monthlyLedgersProvider(filter));

    return Column(children: [
      // 操作栏
      Container(
        padding: const EdgeInsets.all(10),
        color: AppColors.surface,
        child: Column(children: [
          Row(children: [
            _monthPicker(),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _exportMonthly(),
              icon: const Icon(Icons.download, size: 16, color: AppColors.bg),
              label: const Text('导出', style: TextStyle(color: AppColors.bg, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _generate(actions),
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.bg),
              label: const Text('生成', style: TextStyle(color: AppColors.bg, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            ),
          ]),
          const SizedBox(height: 8),
          _statusTabs(),
        ]),
      ),
      Expanded(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (list) => list.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox, size: 48, color: AppColors.text2),
                SizedBox(height: 8),
                Text('暂无核算清单，请先生成', style: TextStyle(color: AppColors.text2)),
              ]))
            : RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async => ref.invalidate(monthlyLedgersProvider(filter)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _buildRow(context, list[i], actions, () => ref.invalidate(monthlyLedgersProvider(filter))),
                ),
              ),
      )),
    ]);
  }

  Widget _monthPicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: '选择月份',
        );
        if (picked != null) {
          setState(() => _selMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_month, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(_selMonth, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 18),
        ]),
      ),
    );
  }

  Widget _statusTabs() {
    final tabs = {'': '全部', 'draft': '草稿', 'submitted': '待审批', 'approved': '已审批'};
    return Wrap(spacing: 6, runSpacing: 6, children: tabs.entries.map((e) {
      final active = _selStatus == e.key || (_selStatus == null && e.key.isEmpty);
      return GestureDetector(
        onTap: () => setState(() => _selStatus = e.key.isEmpty ? null : e.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.gold : AppColors.surface2,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(e.value, style: TextStyle(fontSize: 12, color: active ? AppColors.bg : AppColors.text2, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
    }).toList());
  }

  // ==================== 年度视图 ====================

  Widget _annualBody() {
    final async = ref.watch(annualLedgerProvider(_selYear));

    return Column(children: [
      // 年份选择
      Container(
        padding: const EdgeInsets.all(10),
        color: AppColors.surface,
        child: Row(children: [
          _yearPicker(),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _exportAnnual(),
            icon: const Icon(Icons.download, size: 16, color: AppColors.bg),
            label: const Text('导出', style: TextStyle(color: AppColors.bg, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
          const SizedBox(width: 8),
          Text('${_selYear}年', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
        ]),
      ),
      Expanded(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (list) => list.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox, size: 48, color: AppColors.text2),
                const SizedBox(height: 8),
                Text('暂无 ${_selYear} 年核算数据', style: const TextStyle(color: AppColors.text2)),
                const SizedBox(height: 4),
                const Text('请先生成月度清单', style: TextStyle(color: AppColors.text2, fontSize: 12)),
              ]))
            : RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async => ref.invalidate(annualLedgerProvider(_selYear)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _annualCard(list[i]),
                ),
              ),
      )),
    ]);
  }

  Widget _yearPicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(int.parse(_selYear)),
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: '选择年份',
        );
        if (picked != null) {
          setState(() => _selYear = '${picked.year}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.date_range, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(_selYear, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 18),
        ]),
      ),
    );
  }

  Widget _annualCard(Map<String, dynamic> d) {
    final plate = d['plate_number']?.toString() ?? '';
    final vtype = d['vehicle_type']?.toString() ?? '';
    final monthCount = d['month_count'] ?? 0;
    final approvedCount = d['approved_count'] ?? 0;
    final profit = (d['profit'] as num?)?.toDouble() ?? 0;
    final pfColor = profit >= 0 ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 头部
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$plate ($vtype)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(_selYear, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Text('$approvedCount/$monthCount 月已审批', style: const TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w500)),
          ),
        ]),

        const SizedBox(height: 6),

        // 数据行 — 4列统一对齐
        Table(columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        }, children: [
          TableRow(children: [
            _dataCell('工时', '${(d['total_hours'] as num?)?.toStringAsFixed(1) ?? '0'}h'),
            _dataCell('燃油', '¥${(d['fuel_cost'] as num?)?.toStringAsFixed(2) ?? '0'}'),
            _dataCell('维修', '¥${(d['repair_cost'] as num?)?.toStringAsFixed(2) ?? '0'}'),
            _dataCell('配件', '¥${(d['parts_cost'] as num?)?.toStringAsFixed(2) ?? '0'}'),
          ]),
          TableRow(children: [
            _dataCell('出勤', '${d['work_days'] ?? 0}天'),
            _dataCell('油耗', '${(d['hourly_fuel_consumption'] as num?)?.toStringAsFixed(2) ?? '0'}L/h'),
            _dataCell('成本', '¥${(d['total_cost'] as num?)?.toStringAsFixed(2) ?? '0'}', valueColor: AppColors.danger),
            _dataCell('收入', '¥${(d['revenue'] as num?)?.toStringAsFixed(2) ?? '0'}', valueColor: AppColors.gold),
          ]),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '年度盈亏 ${profit >= 0 ? "+" : "-"}¥${profit.abs().toStringAsFixed(2)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pfColor),
          ),
        ),
      ]),
    );
  }

  // ==================== 趋势视图 ====================

  Widget _trendBody() {
    final filter = TrendFilter(year: _selYear, vehicleId: _selTrendVehicleId);
    final async = ref.watch(vehicleTrendProvider(filter));

    return Column(children: [
      // 控制栏
      Container(
        padding: const EdgeInsets.all(10),
        color: AppColors.surface,
        child: Row(children: [
          _yearPicker(),
          const SizedBox(width: 10),
          if (_selTrendVehicleId != null)
            TextButton.icon(
              onPressed: () => setState(() => _selTrendVehicleId = null),
              icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.gold),
              label: const Text('全部车辆', style: TextStyle(color: AppColors.gold, fontSize: 12)),
            )
          else
            const Text('全部车辆', style: TextStyle(fontSize: 13, color: AppColors.text2)),
        ]),
      ),
      Expanded(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (trends) {
          if (trends.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.inbox, size: 48, color: AppColors.text2),
              const SizedBox(height: 8),
              Text('暂无 $_selYear 年趋势数据', style: const TextStyle(color: AppColors.text2)),
              const SizedBox(height: 4),
              const Text('请先生成月度清单', style: TextStyle(color: AppColors.text2, fontSize: 12)),
            ]));
          }

          // 全部车辆概览模式
          if (_selTrendVehicleId == null) {
            return _buildAllVehiclesTrend(trends);
          }

          // 单车详情模式
          return _buildSingleVehicleTrend(trends.first);
        },
      )),
    ]);
  }

  // ==================== 全部车辆趋势卡片 ====================

  Widget _buildAllVehiclesTrend(List<VehicleTrend> trends) {
    // 筛选有预警的车辆
    final alertVehicles = trends.where((t) => t.alerts.hasRisingAlert).toList();

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async => ref.invalidate(vehicleTrendProvider(TrendFilter(year: _selYear))),
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: trends.length + (alertVehicles.isNotEmpty ? 1 : 0),
        itemBuilder: (ctx, i) {
          // 预警Banner放在第一位
          if (alertVehicles.isNotEmpty && i == 0) {
            return _buildAlertBanner(alertVehicles);
          }
          final idx = alertVehicles.isNotEmpty ? i - 1 : i;
          return _buildTrendCard(trends[idx]);
        },
      ),
    );
  }

  Widget _buildAlertBanner(List<VehicleTrend> alertVehicles) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          const Text('维修费连续上涨预警', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
        ]),
        const SizedBox(height: 8),
        ...alertVehicles.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            const Icon(Icons.circle, size: 6, color: AppColors.danger),
            const SizedBox(width: 6),
            Text(t.vehicleDisplay, style: const TextStyle(fontSize: 12, color: AppColors.text)),
            const SizedBox(width: 8),
            Text('连续${t.alerts.maxRepairRisingConsecutive}个月上涨',
              style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildTrendCard(VehicleTrend t) {
    // 取最近6个月的数据展示走向
    final recent = t.data.length > 6 ? t.data.sublist(t.data.length - 6) : t.data;
    final labels = recent.map((d) => d.monthLabel).toList();
    final repairValues = recent.map((d) => d.repairCost).toList();
    final fuelValues = recent.map((d) => d.fuelCost).toList();
    final partsValues = recent.map((d) => d.partsCost).toList();
    final hfcValues = recent.map((d) => d.hourlyFuelConsumption).toList();
    final totalCostValues = recent.map((d) => d.totalCost).toList();
    final revenueValues = recent.map((d) => d.revenue).toList();

    final bool hasRising = t.alerts.hasRisingAlert;

    return GestureDetector(
      onTap: () => setState(() => _selTrendVehicleId = t.vehicleId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasRising ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 头部
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.vehicleDisplay, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 2),
              Text('${t.data.length}个月数据 · 平均油耗 ${t.alerts.avgHourlyFuelConsumption.toStringAsFixed(1)}L/h',
                style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ])),
            if (hasRising)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('⚠ 连续${t.alerts.maxRepairRisingConsecutive}月上涨',
                  style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.text2),
          ]),

          const SizedBox(height: 8),

          // 横向滚动迷你柱状图行
          SizedBox(
            height: 82,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _buildSparkCell('燃油', fuelValues, AppColors.gold, '¥'),
                const SizedBox(width: 4),
                _buildSparkCell('维修', repairValues, AppColors.danger, '¥'),
                const SizedBox(width: 4),
                _buildSparkCell('配件', partsValues, AppColors.warning, '¥'),
                const SizedBox(width: 4),
                _buildSparkCell('油耗', hfcValues, AppColors.info, 'L/h'),
                const SizedBox(width: 4),
                _buildSparkCell('总成本', totalCostValues, AppColors.danger, '¥'),
                const SizedBox(width: 4),
                _buildSparkCell('收入', revenueValues, AppColors.gold, '¥'),
              ]),
            ),
          ),

          // 月度环比箭头
          if (t.data.length >= 2) ...[
            const SizedBox(height: 8),
            _buildMomArrows(t.data),
          ],

          // 年均数据
          const SizedBox(height: 6),
          Row(children: [
            _summaryChip('年均维修', '¥${t.alerts.avgMonthlyRepairCost.toStringAsFixed(0)}/月'),
            const SizedBox(width: 8),
            _summaryChip('年维修总额', '¥${t.alerts.totalRepairCost.toStringAsFixed(0)}'),
          ]),
        ]),
      ),
    );
  }

  Widget _buildMomArrows(List<TrendMonthData> data) {
    // 计算最后一个月的环比方向
    final last = data.last;
    final changeItems = <Widget>[];

    void addChange(String label, double? change, double? pct) {
      changeItems.add(_changePill(label, change, pct));
    }

    addChange('维修', last.repairCostChange, last.repairCostChangePct);
    addChange('燃油', last.fuelCostChange, last.fuelCostChangePct);
    addChange('总成本', last.totalCostChange, last.totalCostChangePct);

    return Wrap(spacing: 4, runSpacing: 2, children: changeItems);
  }

  Widget _changePill(String label, double? change, double? pct) {
    if (change == null) return const SizedBox.shrink();

    final isUp = change > 0;
    final isDown = change < 0;
    final color = isUp ? AppColors.danger : (isDown ? AppColors.success : AppColors.text2);
    final arrow = isUp ? '↑' : (isDown ? '↓' : '→');
    final pctStr = pct != null ? '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(1)}%' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label $arrow$pctStr',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
    );
  }

  // ==================== 单车趋势详情 ====================

  Widget _buildSingleVehicleTrend(VehicleTrend t) {
    final months = t.data;
    final labels = months.map((d) => d.monthLabel).toList();

    final fuelValues = months.map((d) => d.fuelCost).toList();
    final repairValues = months.map((d) => d.repairCost).toList();
    final partsValues = months.map((d) => d.partsCost).toList();
    final totalCostValues = months.map((d) => d.totalCost).toList();
    final revenueValues = months.map((d) => d.revenue).toList();
    final profitValues = months.map((d) => d.profit).toList();
    final hfcValues = months.map((d) => d.hourlyFuelConsumption).toList();
    final hoursValues = months.map((d) => d.totalHours).toList();
    final daysValues = months.map((d) => d.workDays.toDouble()).toList();

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async => ref.invalidate(vehicleTrendProvider(TrendFilter(year: _selYear, vehicleId: _selTrendVehicleId))),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          // 车辆信息卡片
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.vehicleDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 4),
              Text('${t.model} · $_selYear年 · ${t.data.length}个月数据',
                style: const TextStyle(fontSize: 12, color: AppColors.text2)),
              if (t.alerts.hasRisingAlert) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Text('维修费连续${t.alerts.maxRepairRisingConsecutive}个月上涨，建议关注车辆状况',
                      style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 12),

          // ===== 横向滑动柱状图：全部维度 =====
          SizedBox(
            height: 280,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              child: Row(
                children: List.generate(9, (i) => Padding(
                  padding: EdgeInsets.only(right: i < 8 ? 8 : 0),
                  child: _buildChartItem(i, labels, fuelValues, repairValues, partsValues, totalCostValues, revenueValues, profitValues, hfcValues, hoursValues, daysValues),
                )),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 环比数据表格
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('月度环比明细', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(36),
                    1: FixedColumnWidth(60),
                    2: FixedColumnWidth(54),
                    3: FixedColumnWidth(60),
                    4: FixedColumnWidth(54),
                    5: FixedColumnWidth(60),
                    6: FixedColumnWidth(54),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // 表头
                    TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3)))),
                      children: const [
                        _TableHeader('月份'),
                        _TableHeader('维修费'),
                        _TableHeader('环比'),
                        _TableHeader('燃油费'),
                        _TableHeader('环比'),
                        _TableHeader('总成本'),
                        _TableHeader('利润'),
                      ],
                    ),
                    ...months.map((d) => TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.1)))),
                      children: [
                        _TableCell(d.monthLabel, color: AppColors.text2, fontSize: 11),
                        _TableCell('¥${d.repairCost.toStringAsFixed(0)}', color: AppColors.text),
                        _changeCell(d.repairCostChange, d.repairCostChangePct),
                        _TableCell('¥${d.fuelCost.toStringAsFixed(0)}', color: AppColors.text),
                        _changeCell(d.fuelCostChange, d.fuelCostChangePct),
                        _TableCell('¥${d.totalCost.toStringAsFixed(0)}', color: AppColors.text),
                        _TableCell('¥${d.profit.toStringAsFixed(0)}', color: d.profit >= 0 ? AppColors.success : AppColors.danger),
                      ],
                    )),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 详情页横向滑动图表项
  Widget _buildChartItem(int index, List<String> labels, List<double> f, List<double> r, List<double> p, List<double> t, List<double> rev, List<double> pf, List<double> hfc, List<double> hr, List<double> dy) {
    final meta = const [
      ('燃油', '¥', 0), ('维修', '¥', 0), ('配件', '¥', 0),
      ('总成本', '¥', 0), ('收入', '¥', 0), ('盈亏', '¥', 0),
      ('小时油耗', 'L/h', 1), ('总工时', 'h', 1), ('出勤', '天', 0),
    ];
    final colors = const [AppColors.gold, AppColors.danger, AppColors.warning, AppColors.danger, AppColors.gold, AppColors.success, AppColors.info, AppColors.gold, AppColors.info];
    final allValues = [f, r, p, t, rev, pf, hfc, hr, dy];

    final (title, suffix, decimals) = meta[index];
    final values = allValues[index];
    List<Color>? itemColors;
    if (index == 5) {
      // 盈亏动态颜色
      itemColors = pf.map((v) => v >= 0 ? AppColors.success : AppColors.danger).toList();
    }

    return SizedBox(
      width: 112,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: SimpleBarChart.fromLabels(
          labels: labels,
          values: values,
          colors: itemColors,
          defaultColor: colors[index],
          chartHeight: 200,
          title: title,
          yAxisSuffix: suffix,
          decimalPlaces: decimals,
          horizontal: false,
        ),
      ),
    );
  }

  /// 概览卡片迷你柱状图格（手绘柱体，不依赖SimpleBarChart底部标签区）
  Widget _buildSparkCell(String label, List<double> values, Color color, String suffix) {
    final maxVal = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final niceMax = maxVal <= 0 ? 1.0 : maxVal;
    const double barAreaH = 46.0;
    const barGap = 2.0;

    return SizedBox(
      width: 80,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: barAreaH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: values.asMap().entries.map((e) {
                  final h = niceMax > 0 ? (e.value / niceMax) * barAreaH : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: barGap / 2),
                      child: Container(
                        height: h.clamp(2.0, barAreaH),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _changeCell(double? change, double? pct) {
    if (change == null) {
      return const _TableCell('—', color: AppColors.text2, fontSize: 10);
    }
    final isUp = change > 0;
    final isDown = change < 0;
    final color = isUp ? AppColors.danger : (isDown ? AppColors.success : AppColors.text2);
    final arrow = isUp ? '▲' : (isDown ? '▼' : '—');
    final pctStr = pct != null ? ' ${pct.toStringAsFixed(1)}%' : '';
    return _TableCell('$arrow$pctStr', color: color, fontSize: 10);
  }

  // ==================== 月度卡片 ====================

  Widget _buildRow(BuildContext context, dynamic ledger, dynamic actions, VoidCallback onReload) {
    final statusColor = ledger.isApproved ? AppColors.success : ledger.isSubmitted ? AppColors.warning : AppColors.text2;
    final pfColor = ledger.profit >= 0 ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ledger.isDraft ? AppColors.border : statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 头部
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ledger.vehicleDisplay, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(ledger.yearMonth, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
            child: Text(ledger.statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
          ),
        ]),

        const SizedBox(height: 6),

        // 数据行 — 4列统一对齐
        Table(columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        }, children: [
          TableRow(children: [
            _dataCell('工时', '${ledger.totalHours.toStringAsFixed(1)}h'),
            _dataCell('燃油', '¥${ledger.fuelCost.toStringAsFixed(2)}'),
            _dataCell('维修', '¥${ledger.repairCost.toStringAsFixed(2)}'),
            _dataCell('配件', '¥${ledger.partsCost.toStringAsFixed(2)}'),
          ]),
          TableRow(children: [
            _dataCell('出勤', '${ledger.workDays}天'),
            _dataCell('油耗', '${ledger.hourlyFuelConsumption.toStringAsFixed(2)}L/h'),
            _dataCell('成本', '¥${ledger.totalCost.toStringAsFixed(2)}', valueColor: AppColors.danger),
            _dataCell('收入', '¥${ledger.revenue.toStringAsFixed(2)}', valueColor: AppColors.gold),
          ]),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('盈亏 ${ledger.profitDisplay}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pfColor)),
        ),

        // 操作按钮
        if (ledger.isDraft || ledger.isSubmitted) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (ledger.isDraft)
              ElevatedButton.icon(
                onPressed: () => _submit(ledger.id, actions, onReload),
                icon: const Icon(Icons.send, size: 14),
                label: const Text('提交审核', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              ),
            if (ledger.isSubmitted) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _approve(ledger.id, actions, onReload),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('审批通过', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              ),
            ],
          ]),
        ],
      ]),
    );
  }

  Widget _dataCell(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text2)),
        const SizedBox(height: 1),
        Text(value, style: TextStyle(fontSize: 12, color: valueColor ?? AppColors.text, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ==================== 操作 ====================

  Future<void> _generate(dynamic actions) async {
    try {
      final result = await actions.generateMonthlyLedger(_selMonth);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.msg), backgroundColor: AppColors.success));
        ref.invalidate(monthlyLedgersProvider(MonthlyFilter(yearMonth: _selMonth)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _exportMonthly() async {
    try {
      final csv = await ref.read(ledgerServiceProvider).exportMonthlyCsv(yearMonth: _selMonth);
      final filename = '单车核算月度清单_$_selMonth.csv';
      downloadTextFile(csv, filename);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出成功'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _exportAnnual() async {
    try {
      final csv = await ref.read(ledgerServiceProvider).exportAnnualCsv(year: _selYear);
      final filename = '单车核算年度汇总_$_selYear.csv';
      downloadTextFile(csv, filename);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出成功'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _submit(int id, dynamic actions, VoidCallback onReload) async {
    try {
      await actions.submitMonthlyLedger(id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已提交审核'), backgroundColor: AppColors.success)); onReload(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _approve(int id, dynamic actions, VoidCallback onReload) async {
    try {
      await actions.approveMonthlyLedger(id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('审批通过'), backgroundColor: AppColors.success)); onReload(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }
}

// ==================== 表格小部件 ====================

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: Text(text, style: const TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w600)),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  const _TableCell(this.text, {this.color = AppColors.text, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      child: Text(text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
