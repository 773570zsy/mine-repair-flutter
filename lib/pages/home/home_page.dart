import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import 'home_common.dart';
import 'driver_dashboard.dart';
import 'shop_dashboard.dart';
import 'leader_dashboard.dart';
import 'admin_dashboard.dart';
import 'applicant_dashboard.dart';
import 'dispatcher_dashboard.dart';
import 'safety_dashboard.dart';
import 'external_repair_dashboard.dart';
import '../../widgets/bulletin_board.dart';
import '../../providers/notification_provider.dart';
import 'widgets/local_weather_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    // 监听未读通知数（30秒轮询）
    final unreadAsync = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const AnimatedTitle(),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.waving_hand, size: 14, color: AppColors.gold),
                const SizedBox(width: 4),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: '欢迎您 ', style: TextStyle(fontSize: 12, color: AppColors.text2)),
                  TextSpan(text: '${roleLabel(user.role)}：', style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
                  TextSpan(text: user.name, style: const TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w600)),
                ])),
              ]),
            ),
          // 通知铃铛 + 未读角标
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.email_outlined, size: 20),
                onPressed: () {
                  context.push('/notifications');
                  // 进入时刷新一次未读计数
                  ref.read(unreadCountProvider.notifier).refresh();
                },
              ),
              unreadAsync.whenOrNull(
                    data: (count) => count > 0
                        ? Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.all(Radius.circular(9)),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, maxWidth: 28),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : null,
                  ) ??
                  const SizedBox.shrink(),
            ],
          ),
          IconButton(icon: const Icon(Icons.person_outline, size: 20), onPressed: () => context.push('/profile')),
        ],
      ),
      drawer: user == null ? null : _buildDrawer(context, ref, user),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Column(
              children: [
                const LocalWeatherCard(),
                Expanded(child: _buildDashboard(context, user)),
              ],
            ),
      floatingActionButton: (user != null && user.role != 'applicant')
          ? FloatingActionButton(
              onPressed: () => showDialog(context: context, builder: (_) => const BulletinBoard()),
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              mini: true,
              child: const Text('⚠', style: TextStyle(fontSize: 18)),
            )
          : null,
    );
  }

  // ==================== Drawer ====================

  Widget _buildDrawer(BuildContext context, WidgetRef ref, User user) {
    return Drawer(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        child: Column(children: [
          // 固定头部 — 用户信息
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: AppColors.surface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.gold, child: Text(user.name[0], style: const TextStyle(fontSize: 18, color: Colors.white))),
              const SizedBox(height: 8),
              Text(user.name, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(roleLabel(user.role), style: const TextStyle(color: AppColors.text2, fontSize: 12)),
            ]),
          ),
          // 可滚动菜单区 — 避免窄屏/多菜单时溢出
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _drawerItems(context, user),
            ),
          ),
          // 固定底部 — 退出登录
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger, size: 20),
            title: const Text('退出登录', style: TextStyle(color: AppColors.danger, fontSize: 14)),
            dense: true,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ]),
      ),
    );
  }

  List<Widget> _drawerItems(BuildContext context, User user) {
    final items = <Widget>[
      _drawerTile(Icons.home, '首页', () { Navigator.pop(context); context.go('/home'); }, iconColor: AppColors.gold),
      const Divider(color: AppColors.border, height: 1),
    ];

    if (user.isDriver || user.isRepairShop || user.isLeader || user.isAdmin) {
      items.addAll(_repairMenuItems(context, user));
    }

    // 点检/考勤
    if (user.isDriver || user.isAdmin || user.isLeader) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.assignment_turned_in, '点检', () { Navigator.pop(context); context.push(user.isDriver ? '/inspection/morning-check' : '/inspection/all-records'); }),
        _drawerTile(Icons.access_time, '考勤', () { Navigator.pop(context); context.push(user.isDriver ? '/inspection/attendance' : '/inspection/attendance-report'); }),
      ]);
    }

    // 配件
    if (user.isAdmin || user.isDriver) {
      items.add(_drawerTile(Icons.inventory_2, '配件库存', () { Navigator.pop(context); context.push('/inspection/parts'); }));
    }

    // 工程机械 - 申请人
    if (user.isApplicant) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.engineering, '用车申请', () { Navigator.pop(context); context.push('/machinery/apply'); }),
        _drawerTile(Icons.list_alt, '我的申请', () { Navigator.pop(context); context.push('/machinery/my-applications'); }),
        _drawerTile(Icons.monetization_on, '费用统计', () { Navigator.pop(context); context.push('/machinery/cost-stats'); }),
      ]);
    }

    // 工程机械 - 调度员
    if (user.isDispatcher || user.isAdmin) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.dashboard_customize, '调度看板', () { Navigator.pop(context); context.push('/machinery/kanban'); }, iconColor: AppColors.gold),
        _drawerTile(Icons.pending_actions, '派车-待指派', () { Navigator.pop(context); context.push('/machinery/pending'); }, iconColor: AppColors.warning),
        _drawerTile(Icons.assignment, '派车-全部申请', () { Navigator.pop(context); context.push('/machinery/all'); }),
        _drawerTile(Icons.receipt_long, '派车-已派车', () { Navigator.pop(context); context.push('/machinery/dispatched'); }),
      ]);
    }

    // 工程机械 - 驾驶员
    if (user.isDriver) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.local_shipping, '派车任务', () { Navigator.pop(context); context.push('/machinery/driver-tasks'); }),
      ]);
    }

    // 单车核算 + 保养 — leader/admin
    if (user.isLeader || user.isAdmin) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.account_balance, '单车核算', () { Navigator.pop(context); context.push('/ledger'); }),
        _drawerTile(Icons.build_circle, '保养管理', () { Navigator.pop(context); context.push('/ledger/maintenance'); }, iconColor: AppColors.warning),
      ]);
    }

    // 数据导出/备份/配置 — leader/admin
    if (user.isLeader || user.isAdmin) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.receipt_long, '维修数据导出', () { Navigator.pop(context); context.push('/admin/export'); }),
        _drawerTile(Icons.download, '数据备份', () { Navigator.pop(context); context.push('/admin/backup'); }),
        _drawerTile(Icons.settings, '系统配置', () { Navigator.pop(context); context.push('/admin/config'); }),
      ]);
    }
    // 管理后台 — admin only
    if (user.isAdmin) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.people, '人员管理', () { Navigator.pop(context); context.push('/admin/users'); }, iconColor: AppColors.gold),
      ]);
    }

    // 安全员
    if (user.isSafetyOfficer) {
      items.addAll([
        const Divider(color: AppColors.border, height: 1),
        _drawerTile(Icons.report_problem, '隐患闭环', () { Navigator.pop(context); context.push('/hazard/list'); }, iconColor: AppColors.danger),
        _drawerTile(Icons.assignment_late, '考核通报', () { Navigator.pop(context); context.push('/safety/assessment/list'); }, iconColor: AppColors.danger),
      ]);
    }

    // 照片历史 / 每日一测 — 所有角色
    items.addAll([
      const Divider(color: AppColors.border, height: 1),
      _drawerTile(Icons.photo_library, '照片历史', () { Navigator.pop(context); context.push('/photos'); }),
      _drawerTile(Icons.quiz, '每日一测', () { Navigator.pop(context); context.push('/admin/quiz'); }),
      const Divider(color: AppColors.border, height: 1),
      _drawerTile(Icons.email, '消息通知', () { Navigator.pop(context); context.push('/notifications'); }, iconColor: AppColors.text2),
    ]);
    return items;
  }

  List<Widget> _repairMenuItems(BuildContext context, User user) {
    final items = <Widget>[];
    if (user.isDriver) {
      items.addAll([
        _drawerTile(Icons.add_circle_outline, '发起报修', () { Navigator.pop(context); context.push('/repair/report'); }),
        _drawerTile(Icons.list_alt, '我的报修', () { Navigator.pop(context); context.push('/repair/my-orders'); }),
      ]);
    }
    if (user.isRepairShop) {
      items.addAll([
        _drawerTile(Icons.inbox, '待接工单', () { Navigator.pop(context); context.push('/repair/pending-accept'); }),
        _drawerTile(Icons.list_alt, '我的工单', () { Navigator.pop(context); context.push('/repair/shop-orders'); }),
      ]);
    }
    if (user.isLeader || user.isAdmin) {
      items.addAll([
        _drawerTile(Icons.pending_actions, '待审批报价', () { Navigator.pop(context); context.push('/repair/pending-approval'); }),
        _drawerTile(Icons.assignment, '全部工单', () { Navigator.pop(context); context.push('/repair/all-orders'); }),
      ]);
    }
    return items;
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap, {Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.gold, size: 20),
      title: Text(title, style: const TextStyle(color: AppColors.text, fontSize: 14)),
      dense: true,
      onTap: onTap,
    );
  }

  // ==================== Dashboard ====================

  Widget _buildDashboard(BuildContext context, User user) {
    switch (user.role) {
      case 'driver': return DriverDashboard(pageContext: context);
      case 'repair_shop': return ShopDashboard(pageContext: context);
      case 'leader': return LeaderDashboard(pageContext: context);
      case 'admin': return AdminDashboard(pageContext: context);
      case 'safety_officer': return SafetyOfficerDashboard(pageContext: context);
      case 'applicant': return ApplicantDashboard(pageContext: context);
      case 'dispatcher': return DispatcherDashboard(pageContext: context);
      case 'external_repair': return ExternalRepairDashboard(pageContext: context);
      default: return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.rocket_launch, size: 48, color: AppColors.text2),
        SizedBox(height: 12),
        Text('更多功能即将上线', style: TextStyle(color: AppColors.text2, fontSize: 14)),
      ]));
    }
  }
}
