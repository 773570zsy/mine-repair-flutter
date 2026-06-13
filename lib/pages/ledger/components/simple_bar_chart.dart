import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/color_constants.dart';

/// 零依赖条形图组件 — 纯Container实现
/// 默认横向（horizontal），标签在左，条向右生长
class SimpleBarChart extends StatelessWidget {
  final List<BarItem> items;
  final double chartHeight; // 横向时=总高度，竖向时=图表区高度
  final String? title;
  final String? yAxisSuffix;
  final bool showValueLabels;
  final double? fixedMaxY;
  final int decimalPlaces;
  final bool horizontal; // 默认横向

  const SimpleBarChart({
    required this.items,
    this.chartHeight = 150,
    this.title,
    this.yAxisSuffix,
    this.showValueLabels = true,
    this.fixedMaxY,
    this.decimalPlaces = 1,
    this.horizontal = true,
    super.key,
  });

  factory SimpleBarChart.fromLabels({
    required List<String> labels,
    required List<double> values,
    List<Color>? colors,
    Color defaultColor = AppColors.gold,
    double chartHeight = 150,
    String? title,
    String? yAxisSuffix,
    bool showValueLabels = true,
    double? fixedMaxY,
    int decimalPlaces = 1,
    bool horizontal = true,
  }) {
    return SimpleBarChart(
      items: List.generate(values.length, (i) => BarItem(
        label: labels[i],
        value: values[i],
        color: colors != null && i < colors.length ? colors[i] : defaultColor,
      )),
      chartHeight: chartHeight,
      title: title,
      yAxisSuffix: yAxisSuffix,
      showValueLabels: showValueLabels,
      fixedMaxY: fixedMaxY,
      decimalPlaces: decimalPlaces,
      horizontal: horizontal,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final maxY = fixedMaxY ?? items.fold<double>(0, (m, i) => i.value > m ? i.value : m);
    final niceMax = maxY <= 0 ? 1.0 : _niceMax(maxY);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(title!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 10),
        ],
        if (horizontal)
          _buildHorizontal(niceMax)
        else
          _buildVertical(niceMax),
      ],
    );
  }

  // ==================== 横向条形图 ====================

  Widget _buildHorizontal(double niceMax) {
    final labelWidth = 42.0;
    final valueWidth = showValueLabels ? 56.0 : 0.0;
    final barRowHeight = (chartHeight / items.length).clamp(24.0, 42.0);
    final valueStyle = TextStyle(fontSize: 10, color: AppColors.text2, fontWeight: FontWeight.w500);

    return SizedBox(
      height: chartHeight,
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final ratio = (niceMax > 0 ? (item.value / niceMax) : 0.0).clamp(0.0, 1.0);

          return Padding(
            padding: EdgeInsets.only(bottom: e.key < items.length - 1 ? 6 : 0),
            child: SizedBox(
              height: barRowHeight,
              child: Row(children: [
                // 标签
                SizedBox(
                  width: labelWidth,
                  child: Text(item.label,
                    style: const TextStyle(fontSize: 11, color: AppColors.text2),
                    overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                // 条形区
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: barRowHeight * 0.65,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 数值
                if (showValueLabels)
                  SizedBox(
                    width: valueWidth,
                    child: Text(
                      yAxisSuffix != null
                          ? '$yAxisSuffix${item.value.toStringAsFixed(decimalPlaces)}'
                          : item.value.toStringAsFixed(decimalPlaces),
                      style: valueStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== 竖向柱状图（保留） ====================

  Widget _buildVertical(double niceMax) {
    final barAreaHeight = chartHeight - (showValueLabels ? 24 : 0) - 28;
    final valueTextStyle = TextStyle(fontSize: 10, color: AppColors.text2, height: 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: items.map((item) {
              final barHeight = niceMax > 0
                  ? (item.value / niceMax) * barAreaHeight
                  : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showValueLabels)
                        Text(
                          yAxisSuffix != null
                              ? '$yAxisSuffix${item.value.toStringAsFixed(decimalPlaces)}'
                              : item.value.toStringAsFixed(decimalPlaces),
                          style: valueTextStyle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: barHeight.clamp(2.0, barAreaHeight),
                        decoration: BoxDecoration(
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: items.map((item) => Expanded(
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 9, color: AppColors.text2),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )).toList(),
        ),
      ],
    );
  }

  double _niceMax(double max) {
    if (max <= 0) return 1;
    final magnitude = _pow10(((log(max) / ln10).floor()));
    final normalized = max / magnitude;
    if (normalized <= 1) return magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  double _pow10(int exp) {
    double result = 1;
    if (exp >= 0) {
      for (int i = 0; i < exp; i++) result *= 10;
    } else {
      for (int i = 0; i < -exp; i++) result /= 10;
    }
    return result;
  }
}

class BarItem {
  final String label;
  final double value;
  final Color color;
  const BarItem({required this.label, required this.value, required this.color});
}

/// 图例组件
class ChartLegend extends StatelessWidget {
  final List<LegendItem> items;

  const ChartLegend({required this.items, super.key});

  factory ChartLegend.fromLabels({
    required List<String> labels,
    required List<Color> colors,
  }) {
    return ChartLegend(
      items: List.generate(labels.length, (i) => LegendItem(label: labels[i], color: colors[i])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: items.map((item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(
            color: item.color, borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 4),
          Text(item.label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ],
      )).toList(),
    );
  }
}

class LegendItem {
  final String label;
  final Color color;
  const LegendItem({required this.label, required this.color});
}
