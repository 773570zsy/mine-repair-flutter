import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../providers/admin_provider.dart';
import 'home_common.dart';

/// 管理员仪表盘 — 包含完整管理功能
class AdminDashboard extends ConsumerWidget {
  final BuildContext pageContext;
  const AdminDashboard({required this.pageContext, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(adminDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (dash) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ===== 车辆统计 =====
          StatsRow(items: [
            StatItem(dash.totalVehicles.toString(), '总车辆', icon: Icons.directions_car, onTap: () => context.push('/vehicle-archive/list')),
            StatItem(dash.normalVehicles.toString(), '正常车辆', color: AppColors.success, icon: Icons.check_circle),
            StatItem(dash.repairingCount.toString(), '维修中', color: AppColors.danger, icon: Icons.build_circle, onTap: () => context.push('/repair/all-orders')),
            StatItem(dash.expiredCount.toString(), '保养过期',
              color: dash.expiredCount > 0 ? AppColors.warning : AppColors.text2,
              icon: Icons.warning_amber,
              onTap: dash.expiredCount > 0
                ? () => context.push('/ledger/maintenance')
                : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('暂无符合条件车辆，保养状态良好'),
                    backgroundColor: AppColors.success,
                  )),
            ),
          ]),
          const SizedBox(height: 12),
          // ===== 业务统计 =====
          StatsRow(items: [
            StatItem(dash.pendingApprovalCount.toString(), '待审批报价', color: AppColors.warning, icon: Icons.pending_actions, onTap: () => context.push('/repair/pending-approval')),
            StatItem('—', '待指派用车', icon: Icons.alt_route, onTap: () => context.push('/machinery/pending')),
            StatItem(dash.monthCount.toString(), '本月报修', icon: Icons.build, onTap: () => context.push('/repair/all-orders')),
            StatItem('¥${dash.monthlyCost}', '本月已维修费用', color: AppColors.danger, icon: Icons.monetization_on, onTap: () => context.push('/ledger')),
          ]),
          const SizedBox(height: 12),
          // ===== 系统预警 =====
          AlertsBar(
            maintOverdue: dash.maintOverdue,
            maintSoon: dash.maintSoon,
            partsLowStock: dash.partsLowStock,
            hazardOverdue: dash.hazardOverdue,
            onPartsTap: () => context.push('/inspection/parts'),
          ),
          const SizedBox(height: 12),
          // ===== 功能入口 =====
          Wrap(spacing: 10, runSpacing: 10, children: [
            FeatureCardWide(icon: Icons.folder_open, title: '在编车辆档案', subtitle: '车辆详细档案查阅', onTap: () => context.push('/vehicle-archive/list'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.account_balance, title: '单车核算', subtitle: '油耗/配件/KPI考核', onTap: () => context.push('/ledger'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.build_circle, title: '保养管理', subtitle: '保养状态/记录保养', onTap: () => context.push('/ledger/maintenance'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.people, title: '人员管理', subtitle: '添加/查看用户', onTap: () => context.push('/admin/users'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.assignment, title: '维修进度详情', subtitle: '查看/追溯', onTap: () => context.push('/repair/all-orders'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.receipt_long, title: '维修数据导出', subtitle: '维修工单/费用报表Excel', onTap: () => context.push('/admin/export'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.download, title: '数据备份', subtitle: '备份/恢复数据库', onTap: () => context.push('/admin/backup'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.fact_check, title: '点检记录', subtitle: '每日检查情况', onTap: () => context.push('/inspection/all-records'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.handyman, title: '修理厂管理', subtitle: '管理外包修理厂', onTap: () => context.push('/admin/shops'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.inventory, title: '配件管理', subtitle: '库存/领用/出库', onTap: () => context.push('/inspection/parts'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.badge, title: '员工出勤信息', subtitle: '出勤筛选导出', onTap: () => context.push('/inspection/attendance-report'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.timer_outlined, title: '员工作业工时', subtitle: '工时/公里/加油统计导出', onTap: () => context.push('/inspection/work-hours'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.save_alt, title: '系统配置', subtitle: '油价/台班/阈值', onTap: () => context.push('/admin/config'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.agriculture, title: '用车审批', subtitle: '工程机械派车', onTap: () => context.push('/machinery/pending'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.report_problem, title: '隐患闭环', subtitle: '上报整改确认', onTap: () => context.push('/hazard/list'), borderColor: AppColors.gold),
            FeatureCardWide(icon: Icons.cloud, title: '天气预警', subtitle: '矿区天气/预警管理', onTap: () => context.push('/weather'), borderColor: AppColors.gold),
          ]),
        ]),
      ),
    );
  }
}
