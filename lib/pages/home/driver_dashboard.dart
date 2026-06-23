import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/inspection.dart';
import '../../models/repair_order.dart';
import '../../models/vehicle.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/repair_provider.dart';
import 'home_common.dart';

/// 驾驶员仪表盘
class DriverDashboard extends ConsumerWidget {
  final BuildContext pageContext;
  const DriverDashboard({required this.pageContext, super.key});

  /// 进行中的工单状态（非终态）
  static const _activeStatuses = {
    'pending_accept', 'pending_quote', 'pending_approval',
    'approved', 'repairing', 'completed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 实时数据
    final vehiclesAsync = ref.watch(myVehiclesProvider);
    final ordersAsync = ref.watch(myOrdersProvider(null));
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final recordsAsync = ref.watch(myRecordsProvider(month));

    // 提取数据（加载中用 null）
    final vehicles = vehiclesAsync.whenOrNull(data: (v) => v as List<Vehicle>);
    final orders = ordersAsync.whenOrNull(data: (o) => o as List<RepairOrder>);
    final records = recordsAsync.whenOrNull(data: (r) => r as List<InspectionRecord>);

    // 计算统计值
    final vehicleCount = vehicles?.length ?? 0;
    final activeCount = orders?.where((o) => _activeStatuses.contains(o.status)).length ?? 0;
    final inspectionDone = records?.any((r) => r.inspectionDate == todayStr) ?? false;
    final maintenanceCount = vehicles?.where((v) => v.needsMaintenance).length ?? 0;
    final pendingAcceptCount = orders?.where((o) => o.status == 'completed').length ?? 0;

    final isLoading = vehicles == null || orders == null || records == null;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(myVehiclesProvider);
        ref.invalidate(myOrdersProvider);
        ref.invalidate(myRecordsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ===== 统计卡片行 =====
        _buildStatsRow(vehicleCount, activeCount, inspectionDone, isLoading),
        const SizedBox(height: 12),

        // ===== 保养预警 =====
        AlertCard(
          icon: Icons.warning_amber,
          title: '保养预警',
          subtitle: isLoading
              ? '加载中...'
              : maintenanceCount > 0
                  ? '$maintenanceCount 辆车需要保养，请及时处理'
                  : '所有车辆保养正常',
          color: maintenanceCount > 0 ? AppColors.warning : AppColors.success,
          count: maintenanceCount > 0 ? maintenanceCount : null,
          onTap: maintenanceCount > 0 ? () => pageContext.push('/vehicle-archive/list') : null,
        ),
        const SizedBox(height: 10),

        // ===== 待验收工单 =====
        AlertCard(
          icon: Icons.verified,
          title: '待验收工单',
          subtitle: isLoading
              ? '加载中...'
              : pendingAcceptCount > 0
                  ? '$pendingAcceptCount 个工单维修完毕，请确认验收'
                  : '暂无待验收工单',
          color: pendingAcceptCount > 0 ? AppColors.success : AppColors.text2,
          count: pendingAcceptCount > 0 ? pendingAcceptCount : null,
          onTap: pendingAcceptCount > 0 ? () => pageContext.push('/repair/my-orders') : null,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FeatureCard(icon: Icons.build, title: '快速报修', subtitle: '发起维修工单', onTap: () => context.push('/repair/report'))),
          const SizedBox(width: 10),
          Expanded(child: FeatureCard(icon: Icons.wb_sunny, title: '早检', subtitle: '车辆检查项', onTap: () => context.push('/inspection/morning-check'))),
          const SizedBox(width: 10),
          Expanded(child: FeatureCard(icon: Icons.nights_stay, title: '晚检', subtitle: '工时/加油/停车', onTap: () => context.push('/inspection/evening-check'))),
        ]),
        const SizedBox(height: 10),
        SectionCard(icon: Icons.directions_car, title: '车辆状态总览',
          content: VehicleTable(vehicles: vehicles ?? [], onNavigate: (route) => pageContext.push(route)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FeatureCard(icon: Icons.access_time, title: '今日考勤', subtitle: '出勤打卡', onTap: () => context.push('/inspection/attendance'))),
          const SizedBox(width: 10),
          Expanded(child: FeatureCard(icon: Icons.more_time, title: '今日加班', subtitle: '加班登记', onTap: () => context.push('/inspection/attendance/overtime'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FeatureCard(icon: Icons.folder_open, title: '在编车辆档案', subtitle: '车辆详细档案查阅', onTap: () => context.push('/vehicle-archive/list'))),
          const SizedBox(width: 10),
          Expanded(child: FeatureCard(icon: Icons.local_shipping, title: '派车任务', subtitle: '工程机械', onTap: () => context.push('/machinery/driver-tasks'))),
          const SizedBox(width: 10),
          Expanded(child: FeatureCard(icon: Icons.cloud, title: '天气预警', subtitle: '矿区天气', onTap: () => context.push('/weather'), borderColor: AppColors.gold)),
        ]),
      ]),
    ));
  }

  Widget _buildStatsRow(int vehicleCount, int activeCount, bool inspectionDone, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // 总车辆
        Expanded(
          child: _StatCard(
            value: isLoading ? '...' : '$vehicleCount',
            label: '总车辆',
            icon: Icons.directions_car,
            onTap: () => pageContext.push('/vehicle-archive/list'),
          ),
        ),
        // 进行中工单
        Expanded(
          child: _StatCard(
            value: isLoading ? '...' : '$activeCount',
            label: '进行中工单',
            icon: Icons.build_circle,
            color: activeCount > 0 ? AppColors.gold : AppColors.text,
            onTap: () => pageContext.push('/repair/my-orders'),
          ),
        ),
        // 今日点检
        Expanded(
          child: _StatCard(
            value: isLoading ? '...' : (inspectionDone ? '已完成' : '未点检'),
            label: '今日点检',
            icon: Icons.check_circle,
            color: inspectionDone ? AppColors.success : AppColors.text2,
            valueSize: 16,
            onTap: () => pageContext.push('/inspection/morning-check'),
          ),
        ),
        // 配件领用
        Expanded(
          child: _StatCard(
            value: '...',
            label: '配件领用',
            icon: Icons.inventory_2,
            onTap: () => pageContext.push('/inspection/parts'),
          ),
        ),
        // 每日一测
        Expanded(
          child: _StatCard(
            value: '...',
            label: '每日一测',
            icon: Icons.quiz,
            onTap: () => pageContext.push('/admin/quiz'),
          ),
        ),
      ]),
    );
  }
}

/// 统计卡片小部件（带图标，可点击）
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;
  final double? valueSize;
  final VoidCallback? onTap;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
    this.valueSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 26, color: color ?? AppColors.text),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize ?? 16,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
        ],
      ),
    );
  }
}
