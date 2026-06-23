import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../providers/hazard_provider.dart';
import '../../providers/safety_provider.dart';
import '../../models/hazard.dart';
import '../../models/assessment.dart';

/// 安全员仪表盘
class SafetyOfficerDashboard extends ConsumerWidget {
  final BuildContext pageContext;
  const SafetyOfficerDashboard({required this.pageContext, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazardsAsync = ref.watch(hazardListProvider(null));
    final assessmentsAsync = ref.watch(assessmentListProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(hazardListProvider);
        ref.invalidate(assessmentListProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 统计网格（从 hazards 直接计算，不依赖 alerts API）
        hazardsAsync.when(
          loading: () => _statsRow([_stat('...', '加载中', Icons.hourglass_empty)]),
          error: (_, __) => _statsRow([_stat('!', '加载失败', Icons.error, color: AppColors.danger)]),
          data: (hazards) {
            final now = DateTime.now();
            final pending = hazards.where((h) => h.status != 'verified').length;
            // 从 hazards 直接计算逾期（deadline 已过且未闭环）
            final overdue = hazards.where((h) {
              if (h.status == 'verified') return false;
              if (h.deadline.isEmpty) return false;
              final d = DateTime.tryParse(h.deadline);
              return d != null && d.isBefore(now);
            }).length;
            final verified = hazards.where((h) => h.status == 'verified').length;
            return _statsRow([
              _stat('$pending', '待处理隐患', Icons.warning_amber, color: AppColors.warning),
              _stat('$overdue', '已逾期', Icons.error_outline, color: AppColors.danger),
              _stat('$verified', '已闭环', Icons.verified, color: AppColors.success),
              _stat('⚠', '上报隐患', Icons.add_alert, onTap: () => context.push('/hazard/report')),
              _stat('📋', '考核通报', Icons.assignment_late, color: AppColors.danger, onTap: () => context.push('/safety/assessment/issue')),
            ]);
          },
        ),
        const SizedBox(height: 12),

        // 隐患通报 Tab 列表
        SafetyTabCard(hazardsAsync: hazardsAsync, assessmentsAsync: assessmentsAsync, pageContext: pageContext),
      ]),
    ));
  }

  Widget _statsRow(List<Widget> items) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(children: items.map((i) => Expanded(child: i)).toList()),
    );
  }

  Widget _stat(String value, String label, IconData icon, {Color? color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 26, color: color ?? AppColors.text),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color ?? AppColors.text)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
      ]),
    );
  }
}

// ==================== 安全员 Tab 卡片 ====================

class SafetyTabCard extends ConsumerStatefulWidget {
  final AsyncValue<List<Hazard>> hazardsAsync;
  final AsyncValue<List<Assessment>> assessmentsAsync;
  final BuildContext pageContext;

  const SafetyTabCard({required this.hazardsAsync, required this.assessmentsAsync, required this.pageContext, super.key});

  @override
  ConsumerState<SafetyTabCard> createState() => _SafetyTabCardState();
}

class _SafetyTabCardState extends ConsumerState<SafetyTabCard> {
  String _tab = 'hazard';

  static const _statusMap = {
    'reported': '待指派', 'assigned': '已指派', 'rectifying': '整改中',
    'completed': '待确认', 'verified': '已闭环',
  };

  Color _severityColor(String sv) {
    switch (sv) {
      case '低': return AppColors.success;
      case '一般': return AppColors.warning;
      case '高':
      case '紧急': return AppColors.danger;
      default: return AppColors.text2;
    }
  }

  Color _statusColor(String st) {
    switch (st) {
      case 'reported':
      case 'assigned': return AppColors.warning;
      case 'rectifying': return AppColors.info;
      case 'completed': return AppColors.warning;
      case 'verified': return AppColors.success;
      default: return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('隐患通报列表', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        ]),
        const SizedBox(height: 10),
        _buildTabs(),
        const SizedBox(height: 12),
        _buildContent(),
      ]),
    );
  }

  Widget _buildTabs() {
    const tabs = [
      ('隐患', AppColors.warning, 'hazard'),
      ('通报', AppColors.danger, 'assess'),
      ('已闭环', AppColors.success, 'closed'),
    ] as List<(String, Color, String)>;
    return Wrap(spacing: 6, runSpacing: 6, children: tabs.map((t) {
      final label = t.$1;
      final color = t.$2;
      final key = t.$3;
      final active = _tab == key;
      return GestureDetector(
        onTap: () => setState(() => _tab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color : AppColors.surface2,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12,
            color: active ? AppColors.surface : AppColors.text2,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          )),
        ),
      );
    }).toList());
  }

  Widget _buildContent() {
    switch (_tab) {
      case 'hazard': return _buildHazardList();
      case 'assess': return _buildAssessList();
      case 'closed': return _buildClosedList();
      default: return const SizedBox.shrink();
    }
  }

  static const _thStyle = TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600);
  static const _tdStyle = TextStyle(fontSize: 13, color: AppColors.text);
  static const _td2Style = TextStyle(fontSize: 13, color: AppColors.text2);
  static const _tdSmall = TextStyle(fontSize: 12, color: AppColors.text2);
  static const _tdGold = TextStyle(fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w500);
  static const _hzCols = {0: FlexColumnWidth(3), 1: FlexColumnWidth(3), 2: FlexColumnWidth(0.9), 3: FlexColumnWidth(3), 4: FlexColumnWidth(1.2), 5: FlexColumnWidth(2), 6: FlexColumnWidth(1)};
  static const _asCols = {0: FlexColumnWidth(3), 1: FlexColumnWidth(3), 2: FlexColumnWidth(3), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(3), 5: FlexColumnWidth(2), 6: FlexColumnWidth(1)};

  TableRow _headerRow(List<String> cols) {
    return TableRow(
      decoration: const BoxDecoration(color: AppColors.surface2, border: Border(bottom: BorderSide(color: AppColors.border))),
      children: cols.map((c) => _cell(c, _thStyle, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8))).toList(),
    );
  }

  Widget _cell(dynamic content, TextStyle? style, {EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 9, horizontal: 8)}) {
    return Padding(
      padding: padding,
      child: content is String ? Text(content, style: style, overflow: TextOverflow.ellipsis) : content as Widget,
    );
  }

  Widget _tappableCell(dynamic content, TextStyle? style, String route, {bool overflow = false}) {
    return InkWell(
      onTap: () => widget.pageContext.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        child: content is String
            ? Text(content, style: style, overflow: overflow ? TextOverflow.ellipsis : null)
            : content as Widget,
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _viewAllBtn(String route) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(child: GestureDetector(
        onTap: () => widget.pageContext.push(route),
        child: const Text('查看全部 →', style: TextStyle(color: AppColors.gold, fontSize: 12)),
      )),
    );
  }

  Widget _buildHazardList() {
    return widget.hazardsAsync.when(
      loading: () => _loading(),
      error: (_, __) => const Padding(padding: EdgeInsets.all(20), child: Text('加载失败', style: TextStyle(color: AppColors.danger, fontSize: 13))),
      data: (hazards) {
        if (hazards.isEmpty) return _empty('暂无隐患记录');
        final recent = hazards.take(10).toList();
        return Column(children: [
          Table(columnWidths: _hzCols, children: [
            _headerRow(['编号', '地点', '程度', '整改人', '状态', '期限', '操作']),
            for (final h in recent) _hazardRow(h),
          ]),
          if (hazards.length > 10) _viewAllBtn('/hazard/list'),
        ]);
      },
    );
  }

  Widget _buildAssessList() {
    return widget.assessmentsAsync.when(
      loading: () => _loading(),
      error: (_, __) => const Padding(padding: EdgeInsets.all(20), child: Text('加载失败', style: TextStyle(color: AppColors.danger, fontSize: 13))),
      data: (list) {
        if (list.isEmpty) return _empty('暂无通报记录');
        final recent = list.take(10).toList();
        final typeColors = {'表扬': AppColors.success, '通报': AppColors.warning, '警告': AppColors.danger, '处罚': AppColors.danger};
        return Column(children: [
          Table(columnWidths: _asCols, children: [
            _headerRow(['编号', '标题', '被考核人', '类型', '下发人', '日期', '操作']),
            for (final a in recent) _assessRow(a, typeColors),
          ]),
          if (list.length > 10) _viewAllBtn('/safety/assessment/list'),
        ]);
      },
    );
  }

  Widget _buildClosedList() {
    return widget.hazardsAsync.when(
      loading: () => _loading(),
      error: (_, __) => const Padding(padding: EdgeInsets.all(20), child: Text('加载失败', style: TextStyle(color: AppColors.danger, fontSize: 13))),
      data: (hazards) {
        final closed = hazards.where((h) => h.status == 'verified').toList();
        if (closed.isEmpty) return _empty('暂无已闭环记录');
        return Table(columnWidths: _hzCols, children: [
          _headerRow(['编号', '地点', '程度', '整改人', '状态', '期限', '操作']),
          for (final h in closed) _hazardRow(h),
        ]);
      },
    );
  }

  Widget _loading() => const Center(child: Padding(padding: EdgeInsets.all(20), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))));
  Widget _empty(String msg) => Padding(padding: const EdgeInsets.all(20), child: Text(msg, style: const TextStyle(color: AppColors.text2, fontSize: 13)));

  TableRow _hazardRow(Hazard h) {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      children: [
        _tappableCell(h.hazardNo, _tdStyle, '/hazard/detail/${h.id}'),
        _tappableCell(h.location.isNotEmpty ? h.location : '-', _td2Style, '/hazard/detail/${h.id}', overflow: true),
        _tappableCell(_miniTag(h.severity, _severityColor(h.severity)), null, '/hazard/detail/${h.id}'),
        _tappableCell(h.responsibleName ?? '-', _td2Style, '/hazard/detail/${h.id}', overflow: true),
        _tappableCell(_miniTag(_statusMap[h.status] ?? h.status, _statusColor(h.status)), null, '/hazard/detail/${h.id}'),
        _tappableCell(h.deadline.isNotEmpty ? h.deadline : '-', _tdSmall, '/hazard/detail/${h.id}'),
        _tappableCell('详情', _tdGold, '/hazard/detail/${h.id}'),
      ],
    );
  }

  TableRow _assessRow(Assessment a, Map<String, Color> typeColors) {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      children: [
        _tappableCell(a.assessNo, _tdStyle, '/safety/assessment/detail/${a.id}'),
        _tappableCell(a.title, _td2Style, '/safety/assessment/detail/${a.id}', overflow: true),
        _tappableCell(a.targetName ?? '-', _td2Style, '/safety/assessment/detail/${a.id}', overflow: true),
        _tappableCell(_miniTag(a.assessType, typeColors[a.assessType] ?? AppColors.text2), null, '/safety/assessment/detail/${a.id}'),
        _tappableCell(a.issuerName ?? '-', _td2Style, '/safety/assessment/detail/${a.id}', overflow: true),
        _tappableCell(a.createdAt.length >= 10 ? a.createdAt.substring(0, 10) : '', _tdSmall, '/safety/assessment/detail/${a.id}'),
        _tappableCell('详情', _tdGold, '/safety/assessment/detail/${a.id}'),
      ],
    );
  }
}
