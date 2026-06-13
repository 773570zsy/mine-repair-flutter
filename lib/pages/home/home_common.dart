import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../config/constants.dart';

// ==================== 角色标签 ====================

String roleLabel(String role) {
  return roleMap[role] ?? role;
}

// ==================== 统计卡片 ====================

class StatsRow extends StatelessWidget {
  final List<Widget> items;
  const StatsRow({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: items.map((i) => Expanded(child: i)).toList()),
    );
  }
}

class StatItem extends StatelessWidget {
  final String value, label;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatItem(this.value, this.label, {this.color, this.icon, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          if (icon != null)
            Icon(icon, size: 26, color: color ?? AppColors.text)
          else
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color ?? AppColors.text)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        ],
      ),
    );
  }
}

// ==================== 预警卡片（横排四段） ====================

class AlertCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final int? count;
  final VoidCallback? onTap;

  const AlertCard({required this.icon, required this.title, required this.subtitle, required this.color, this.count, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
          ])),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.text2),
          ],
        ]),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// 横排预警条 — 四段等分，竖线分隔，无图标
class AlertsBar extends StatelessWidget {
  final int maintOverdue;
  final int maintSoon;
  final int partsLowStock;
  final int hazardOverdue;
  final VoidCallback? onPartsTap;

  const AlertsBar({
    this.maintOverdue = 0,
    this.maintSoon = 0,
    this.partsLowStock = 0,
    this.hazardOverdue = 0,
    this.onPartsTap,
    super.key,
  });

  bool get hasAny => maintOverdue > 0 || maintSoon > 0 || partsLowStock > 0 || hazardOverdue > 0;

  @override
  Widget build(BuildContext context) {
    if (!hasAny) {
      return SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Text('系统状态正常，暂无预警事项',
              style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            _seg(context, '保养过期', maintOverdue, AppColors.danger, null),
            _divider(),
            _seg(context, '即将到期', maintSoon, AppColors.warning, null),
            _divider(),
            _seg(context, '库存不足', partsLowStock, AppColors.warning, onPartsTap),
            _divider(),
            _seg(context, '隐患逾期', hazardOverdue, AppColors.danger, null),
          ]),
        ),
      ),
    );
  }

  Widget _seg(BuildContext context, String label, int count, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(count > 0 ? '$count' : '0',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: count > 0 ? color : AppColors.text2)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
        ]),
      ),
    );
  }

  Widget _divider() {
    return const SizedBox(
      height: 36,
      child: VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
    );
  }
}

// ==================== 功能卡片 ====================

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? borderColor;

  const FeatureCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.borderColor, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 28, color: AppColors.gold),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.text2), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class FeatureCardWide extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? borderColor;

  const FeatureCardWide({required this.icon, required this.title, required this.subtitle, required this.onTap, this.borderColor, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 28, color: AppColors.gold),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.text2), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ==================== 区块卡片 ====================

class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;

  const SectionCard({required this.icon, required this.title, required this.content, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          ]),
          const SizedBox(height: 10),
          content,
        ]),
      ),
    );
  }
}

// ==================== Tab ====================

class DashTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const DashTab({required this.label, required this.active, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surface2,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          color: active ? AppColors.bg : AppColors.text2,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }
}

// ==================== 表格行 ====================

class DashTableRow extends StatelessWidget {
  final List<String> cells;
  final bool header;

  const DashTableRow(this.cells, {this.header = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
        color: header ? AppColors.surface2 : null,
      ),
      child: Row(
        children: cells.map((c) => Expanded(child: Text(c, style: TextStyle(
          fontSize: 12,
          color: header ? AppColors.text2 : AppColors.text,
          fontWeight: header ? FontWeight.w600 : FontWeight.normal,
        )))).toList(),
      ),
    );
  }
}

// ==================== 车辆表格（静态演示） ====================

class VehicleTable extends StatelessWidget {
  const VehicleTable({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      DashTableRow(['内部编号', '类型', '型号', '工时', '保养', '状态'], header: true),
      DashTableRow(['KM-TEST', '汽车吊', 'TEST', '0h', '610h', '正常']),
    ]);
  }
}

// ==================== 修理厂工单Tab面板 ====================

class ShopOrderTabs extends StatelessWidget {
  final BuildContext pageContext;
  const ShopOrderTabs({required this.pageContext, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 6, runSpacing: 6,
        children: ['全部', '待接单', '待报价', '待审批', '维修中', '已驳回', '待验收', '已完成']
            .map((t) => DashTab(label: t, active: t == '全部', onTap: () {}))
            .toList(),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: () => pageContext.push('/repair/shop-orders'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: const DashTableRow(['工单号', '车辆', '报修人', '状态', '操作'], header: true),
        ),
      ),
      const DashTableRow(['JL202606099104', 'KM-TEST', '张三', '待报价', '详情']),
      const SizedBox(height: 8),
      Center(child: TextButton(
        onPressed: () => pageContext.push('/repair/shop-orders'),
        child: const Text('查看全部工单 →', style: TextStyle(color: AppColors.gold, fontSize: 13)),
      )),
    ]);
  }
}

// ==================== 带动画图标的标题 ====================

class AnimatedTitle extends StatefulWidget {
  const AnimatedTitle({super.key});

  @override
  State<AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<AnimatedTitle> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        RotationTransition(
          turns: _ctrl,
          child: Transform.scale(
            scaleX: -1,
            child: const Icon(Icons.sync, color: AppColors.gold, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        const Text.rich(TextSpan(children: [
          TextSpan(text: '总调度室', style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w700)),
          TextSpan(text: '综合管理系统', style: TextStyle(color: AppColors.gold2, fontSize: 16, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}
