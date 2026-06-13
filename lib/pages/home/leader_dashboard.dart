import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../providers/admin_provider.dart';
import 'home_common.dart';

/// 科级审批员仪表盘 — 聚焦待审批报价 + 工单概览
class LeaderDashboard extends ConsumerWidget {
  final BuildContext pageContext;
  const LeaderDashboard({required this.pageContext, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(adminDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (dash) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ===== 核心统计 =====
          StatsRow(items: [
            StatItem(dash.pendingApprovalCount.toString(), '待审批报价',
              color: dash.pendingApprovalCount > 0 ? AppColors.danger : AppColors.text2,
              icon: Icons.pending_actions,
              onTap: () => context.push('/repair/pending-approval')),
            StatItem('—', '今日审批', icon: Icons.check_circle_outline, onTap: () => context.push('/repair/all-orders')),
            StatItem(dash.monthCount.toString(), '本月报修', icon: Icons.build, onTap: () => context.push('/repair/all-orders')),
            StatItem('¥${dash.monthlyCost}', '本月费用', color: AppColors.danger, icon: Icons.monetization_on, onTap: () => context.push('/ledger')),
          ]),
          const SizedBox(height: 12),
          // ===== 待审批提醒 =====
          if (dash.pendingApprovalCount > 0)
            AlertCard(
              icon: Icons.warning_amber,
              title: '您有 ${dash.pendingApprovalCount} 条待审批报价',
              subtitle: '点击进入审批页面进行处理',
              color: AppColors.danger,
            )
          else
            AlertCard(
              icon: Icons.check_circle,
              title: '暂无待审批报价',
              subtitle: '一切正常',
              color: AppColors.success,
            ),
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

          // ===== 快捷入口（审批相关） =====
          Wrap(spacing: 10, runSpacing: 10, children: [
            FeatureCardWide(
              icon: Icons.pending_actions,
              title: '待审批报价',
              subtitle: '审核报价并批复',
              onTap: () => context.push('/repair/pending-approval'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.assignment,
              title: '全部工单',
              subtitle: '查看/追溯所有维修',
              onTap: () => context.push('/repair/all-orders'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.receipt_long,
              title: '维修数据导出',
              subtitle: '导出工单/费用报表',
              onTap: () => context.push('/admin/export'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.folder_open,
              title: '在编车辆档案',
              subtitle: '车辆详细档案查阅',
              onTap: () => context.push('/vehicle-archive/list'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.fact_check,
              title: '点检记录',
              subtitle: '每日检查情况',
              onTap: () => context.push('/inspection/all-records'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.badge,
              title: '员工出勤',
              subtitle: '出勤筛选导出',
              onTap: () => context.push('/inspection/attendance-report'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.timer_outlined,
              title: '员工作业工时',
              subtitle: '工时/公里/加油统计',
              onTap: () => context.push('/inspection/work-hours'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.agriculture,
              title: '用车审批',
              subtitle: '工程机械派车',
              onTap: () => context.push('/machinery/pending'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.report_problem,
              title: '隐患闭环',
              subtitle: '上报整改确认',
              onTap: () => context.push('/hazard/list'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.cloud,
              title: '天气预警',
              subtitle: '矿区天气/预警管理',
              onTap: () => context.push('/weather'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.account_balance,
              title: '单车核算',
              subtitle: '油耗/配件/KPI考核',
              onTap: () => context.push('/ledger'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.build_circle,
              title: '保养管理',
              subtitle: '保养状态/记录保养',
              onTap: () => context.push('/ledger/maintenance'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.download,
              title: '数据备份',
              subtitle: '备份/恢复数据库',
              onTap: () => context.push('/admin/backup'),
              borderColor: AppColors.gold,
            ),
            FeatureCardWide(
              icon: Icons.settings,
              title: '系统配置',
              subtitle: '油价/台班/阈值',
              onTap: () => context.push('/admin/config'),
              borderColor: AppColors.gold,
            ),
          ]),
        ]),
      ),
    );
  }
}
