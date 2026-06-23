import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/application_analysis.dart';
import '../../services/machinery_service.dart';

class ApplicationAnalysisPage extends StatefulWidget {
  const ApplicationAnalysisPage({super.key});

  @override
  State<ApplicationAnalysisPage> createState() => _ApplicationAnalysisPageState();
}

class _ApplicationAnalysisPageState extends State<ApplicationAnalysisPage> {
  String _period = 'month';
  late Future<ApplicationAnalysis> _future;

  static const _periodLabels = {'day': '按日', 'month': '按月', 'year': '按年'};
  static const _colors = [
    Color(0xFF5a9e5f), Color(0xFF2980b9), Color(0xFFc8a04a),
    Color(0xFFe05555), Color(0xFF8e44ad), Color(0xFFd35400),
    Color(0xFF1abc9c), Color(0xFF2c3e50), Color(0xFFe67e22),
    Color(0xFF3498db), Color(0xFF9b59b6), Color(0xFF27ae60),
  ];

  @override
  void initState() {
    super.initState();
    _future = MachineryService().getApplicationAnalysis(period: _period);
  }

  Future<void> _loadData([String? period]) async {
    final p = period ?? _period;
    final f = MachineryService().getApplicationAnalysis(period: p);
    setState(() {
      _period = p;
      _future = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('申请分析'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold, size: 20),
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: Column(children: [
        // 时间段切换
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.surface,
          child: Row(children: ['day', 'month', 'year'].map((p) {
            final active = _period == p;
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: p == 'year' ? 0 : 6),
              child: GestureDetector(
                onTap: () => _loadData(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.gold.withValues(alpha: 0.2) : AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: active ? AppColors.gold : AppColors.border),
                  ),
                  child: Text(_periodLabels[p]!, textAlign: TextAlign.center,
                    style: TextStyle(color: active ? AppColors.gold : AppColors.text2, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            ));
          }).toList()),
        ),
        // 内容
        Expanded(child: FutureBuilder<ApplicationAnalysis>(
          future: _future,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snap.hasError) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                const SizedBox(height: 8),
                Text('${snap.error}', style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => _loadData(), child: const Text('重试')),
              ]));
            }
            final d = snap.data!;
            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: () async => _loadData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  _buildSummary(d),
                  const SizedBox(height: 16),
                  if (d.byType.isNotEmpty) ...[
                    _buildTypeBarChart(d),
                    const SizedBox(height: 16),
                  ],
                  if (d.trend.isNotEmpty) ...[
                    _buildTrendLineChart(d),
                    const SizedBox(height: 16),
                  ],
                  if (d.vehicleRanking.isNotEmpty) ...[
                    _buildVehicleRanking(d),
                    const SizedBox(height: 16),
                  ],
                  if (d.byType.isEmpty && d.trend.isEmpty && d.vehicleRanking.isEmpty)
                    const Padding(padding: EdgeInsets.all(40), child: Text('暂无数据', style: TextStyle(color: AppColors.text2, fontSize: 14))),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  // ===== 统计概览 =====
  Widget _buildSummary(ApplicationAnalysis d) {
    return Row(children: [
      _statCard('总申请数', '${d.totalCount}', Icons.assignment_outlined, AppColors.gold),
      const SizedBox(width: 8),
      _statCard('涉及车型', '${d.byType.length}', Icons.directions_car_outlined, const Color(0xFF2980b9)),
      const SizedBox(width: 8),
      _statCard('被派车辆', '${d.vehicleRanking.length}', Icons.local_shipping_outlined, AppColors.success),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 11)),
        ]),
      ),
    );
  }

  // ===== 车型分布柱状图 =====
  Widget _buildTypeBarChart(ApplicationAnalysis d) {
    return _section('车型申请分布', Icons.bar_chart_outlined, SizedBox(
      height: max(220.0, d.byType.length * 36.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (d.byType.first.count * 1.2).toDouble(),
          barGroups: d.byType.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: t.count.toDouble(),
                color: _colors[i % _colors.length],
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.text2, fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= d.byType.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(d.byType[idx].vehicleType, style: const TextStyle(color: AppColors.text2, fontSize: 10), overflow: TextOverflow.ellipsis),
              );
            })),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, horizontalInterval: max(1, (d.byType.first.count / 4).ceilToDouble().toDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withValues(alpha: 0.3), strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
        ),
        duration: const Duration(milliseconds: 300),
      ),
    ));
  }

  // ===== 趋势折线图 =====
  Widget _buildTrendLineChart(ApplicationAnalysis d) {
    // 获取所有在趋势中出现的车型
    final allTypes = <String>{};
    for (final t in d.trend) { allTypes.addAll(t.types.keys); }
    final topTypes = allTypes.toList()..sort((a, b) {
      final ca = d.trend.fold<int>(0, (s, t) => s + (t.types[a] ?? 0));
      final cb = d.trend.fold<int>(0, (s, t) => s + (t.types[b] ?? 0));
      return cb.compareTo(ca);
    });
    final showTypes = topTypes.take(6).toList();

    return _section('申请趋势', Icons.trending_up_outlined, SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          lineBarsData: showTypes.asMap().entries.map((e) {
            final color = _colors[e.key % _colors.length];
            return LineChartBarData(
              spots: d.trend.asMap().entries.map((te) {
                return FlSpot(te.key.toDouble(), (te.value.types[e.value] ?? 0).toDouble());
              }).toList(),
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(show: true, getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0)),
              belowBarData: BarAreaData(show: false),
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.text2, fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= d.trend.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_period == 'day' ? d.trend[idx].label.substring(5) : d.trend[idx].label, style: const TextStyle(color: AppColors.text2, fontSize: 9)),
              );
            })),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withValues(alpha: 0.3), strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
        ),
        duration: const Duration(milliseconds: 300),
      ),
    ));
  }

  // ===== 车辆被派排名 =====
  Widget _buildVehicleRanking(ApplicationAnalysis d) {
    return _section('车辆被派排名', Icons.emoji_events_outlined, Column(children: [
      ...d.vehicleRanking.asMap().entries.map((e) {
        final i = e.key;
        final v = e.value;
        final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3)))),
          child: Row(children: [
            SizedBox(width: 24, child: Text(medal, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.plateNumber, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(v.vehicleType, style: const TextStyle(color: AppColors.text2, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _colors[i % _colors.length].withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(v.countLabel, style: TextStyle(color: _colors[i % _colors.length], fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }),
    ]));
  }

  // ===== 工具方法 =====
  Widget _section(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  double max(double a, double b) => a > b ? a : b;
}
