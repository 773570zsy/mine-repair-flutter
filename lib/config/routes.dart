import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import 'guards.dart';
import '../pages/login/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/notification/notification_page.dart';
// 维修
import '../pages/repair/report_fault_page.dart';
import '../pages/repair/my_orders_page.dart';
import '../pages/repair/pending_accept_page.dart';
import '../pages/repair/shop_orders_page.dart';
import '../pages/repair/submit_quote_page.dart';
import '../pages/repair/update_progress_page.dart';
import '../pages/repair/pending_approval_page.dart';
import '../pages/repair/all_orders_page.dart';
import '../pages/repair/order_detail_page.dart';
import '../pages/repair/trial_accept_page.dart';
// 外部报修
import '../pages/external_repair/report_external_page.dart';
import '../pages/external_repair/my_external_requests_page.dart';
import '../pages/external_repair/external_pending_accept_page.dart';
import '../pages/external_repair/external_shop_orders_page.dart';
import '../pages/external_repair/external_pending_approval_page.dart';
import '../pages/external_repair/external_all_orders_page.dart';
import '../pages/external_repair/external_order_detail_page.dart';
import '../pages/external_repair/external_repair_home_page.dart';
// 隐患
import '../pages/hazard/hazard_list_page.dart';
import '../pages/hazard/hazard_report_page.dart';
import '../pages/hazard/hazard_detail_page.dart';
// 考核
import '../pages/safety/assessment_list_page.dart';
import '../pages/safety/assessment_form_page.dart';
import '../pages/safety/assessment_detail_page.dart';
// 点检/考勤/配件
import '../pages/inspection/morning_check_page.dart';
import '../pages/inspection/evening_check_page.dart';
import '../pages/inspection/my_records_page.dart';
import '../pages/inspection/all_records_page.dart';
import '../pages/inspection/today_summary_page.dart';
import '../pages/inspection/attendance_page.dart';
import '../pages/inspection/attendance_report_page.dart';
import '../pages/admin/work_hours_page.dart';
import '../pages/inspection/parts_list_page.dart';
import '../pages/inspection/parts_requisition_page.dart';
import '../pages/inspection/parts_management_page.dart';
// 车辆档案
import '../pages/vehicle_archive/archive_list_page.dart';
import '../pages/vehicle_archive/archive_detail_page.dart';
import '../pages/vehicle_archive/archive_form_page.dart';
// 天气
import '../pages/weather/weather_dashboard_page.dart';
import '../pages/weather/weather_warning_list_page.dart';
import '../pages/weather/weather_zone_page.dart';
import '../pages/weather/weather_warning_detail_page.dart';
import '../pages/weather/weather_threshold_page.dart';
// 工程机械
import '../pages/machinery/apply_page.dart';
import '../pages/machinery/my_applications_page.dart';
import '../pages/machinery/application_detail_page.dart';
import '../pages/machinery/pending_list_page.dart';
import '../pages/machinery/all_applications_page.dart';
import '../pages/machinery/assign_page.dart';
import '../pages/machinery/driver_tasks_page.dart';
import '../pages/machinery/cost_stats_page.dart';
import '../pages/machinery/dispatched_page.dart';
import '../pages/machinery/dispatch_export_page.dart';
import '../pages/machinery/kanban_page.dart';
import '../pages/machinery/assigned_history_page.dart';
import '../pages/machinery/application_analysis_page.dart';
// 单车核算
import '../pages/ledger/ledger_home_page.dart';
import '../pages/ledger/monthly_ledger_page.dart';
import '../pages/ledger/kpi_ranking_page.dart';
import '../pages/ledger/threshold_config_page.dart';
import '../pages/ledger/maintenance_page.dart';
import '../pages/ledger/budget_page.dart';
import '../pages/ledger/budget_config_page.dart';
import '../pages/ledger/budget_import_page.dart';
// 管理后台
// admin_home_page.dart removed — functionality moved to leader dashboard
import '../pages/admin/user_management_page.dart';
// 照片历史
import '../pages/photo_history_page.dart';
// 开发工具
import '../utils/icon_generator.dart';
// vehicle_admin_page.dart removed — merged into archive_list_page.dart
import '../pages/admin/shop_management_page.dart';
import '../pages/admin/export_page.dart';
import '../pages/admin/backup_page.dart';
import '../pages/admin/config_page.dart';
import '../pages/admin/quiz_page.dart';

/// 全局 Router 引用，供 JPush 通知点击跳转使用
GoRouter? globalRouter;

/// 全局导航 Key，供 JPush 通知点击跳转使用
final navigatorKey = GlobalKey<NavigatorState>();

/// GoRouter 完整路由配置
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isLoginPage = state.matchedLocation == '/login';
      final user = authState.user;

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/home';

      if (isLoggedIn && user != null) {
        // external_repair 用户登录后直达外部报修首页
        if (user.isExternalRepair && state.matchedLocation == '/home') {
          return '/external-repair/home';
        }
        return roleRouteGuard(user, state.matchedLocation);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/home', builder: (c, s) => const HomePage()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationPage()),
      GoRoute(path: '/photos', builder: (c, s) => const PhotoHistoryPage()),

      // ========== 维修 ==========
      GoRoute(path: '/repair/report', builder: (c, s) => const ReportFaultPage()),
      GoRoute(path: '/repair/my-orders', builder: (c, s) => const MyOrdersPage()),
      GoRoute(path: '/repair/pending-accept', builder: (c, s) => const PendingAcceptPage()),
      GoRoute(path: '/repair/shop-orders', builder: (c, s) => const ShopOrdersPage()),
      GoRoute(path: '/repair/submit-quote/:orderId', builder: (c, s) {
        final orderId = int.parse(s.pathParameters['orderId']!);
        final reQuote = s.uri.queryParameters['reQuote'] == '1';
        return SubmitQuotePage(orderId: orderId, isReQuote: reQuote);
      }),
      GoRoute(path: '/repair/update-progress/:orderId', builder: (c, s) {
        final orderId = int.parse(s.pathParameters['orderId']!);
        final complete = s.uri.queryParameters['complete'] == '1';
        return UpdateProgressPage(orderId: orderId, isComplete: complete);
      }),
      GoRoute(path: '/repair/pending-approval', builder: (c, s) => const PendingApprovalPage()),
      GoRoute(path: '/repair/all-orders', builder: (c, s) => const AllOrdersPage()),
      GoRoute(path: '/repair/detail/:orderId', builder: (c, s) {
        final orderId = int.parse(s.pathParameters['orderId']!);
        return OrderDetailPage(orderId: orderId);
      }),
      GoRoute(path: '/repair/trial-accept/:orderId', builder: (c, s) {
        final orderId = int.parse(s.pathParameters['orderId']!);
        return TrialAcceptPage(orderId: orderId);
      }),

      // ========== 外部报修 ==========
      GoRoute(path: '/external-repair/home', builder: (c, s) => const ExternalRepairHomePage()),
      GoRoute(path: '/external-repair/report', builder: (c, s) => const ReportExternalPage()),
      GoRoute(path: '/external-repair/my-requests', builder: (c, s) => const MyExternalRequestsPage()),
      GoRoute(path: '/external-repair/pending-accept', builder: (c, s) => const ExternalPendingAcceptPage()),
      GoRoute(path: '/external-repair/shop-orders', builder: (c, s) => const ExternalShopOrdersPage()),
      GoRoute(path: '/external-repair/pending-approval', builder: (c, s) => const ExternalPendingApprovalPage()),
      GoRoute(path: '/external-repair/all-orders', builder: (c, s) => const ExternalAllOrdersPage()),
      GoRoute(path: '/external-repair/detail/:orderId', builder: (c, s) {
        final orderId = int.parse(s.pathParameters['orderId']!);
        return ExternalOrderDetailPage(orderId: orderId);
      }),

      // ========== 隐患 ==========
      GoRoute(path: '/hazard/list', builder: (c, s) => const HazardListPage()),
      GoRoute(path: '/hazard/report', builder: (c, s) => const HazardReportPage()),
      GoRoute(path: '/hazard/detail/:hazardId', builder: (c, s) {
        final hazardId = int.parse(s.pathParameters['hazardId']!);
        return HazardDetailPage(hazardId: hazardId);
      }),

      // ========== 考核 ==========
      GoRoute(path: '/safety/assessment/list', builder: (c, s) => const AssessmentListPage()),
      GoRoute(path: '/safety/assessment/issue', builder: (c, s) => const AssessmentFormPage()),
      GoRoute(path: '/safety/assessment/detail/:assessmentId', builder: (c, s) {
        final assessmentId = int.parse(s.pathParameters['assessmentId']!);
        return AssessmentDetailPage(assessmentId: assessmentId);
      }),

      // ========== 点检 ==========
      GoRoute(path: '/inspection/morning-check', builder: (c, s) => const MorningCheckPage()),
      GoRoute(path: '/inspection/evening-check', builder: (c, s) => const EveningCheckPage()),
      GoRoute(path: '/inspection/my-records', builder: (c, s) => const MyRecordsPage()),
      GoRoute(path: '/inspection/all-records', builder: (c, s) => const AllRecordsPage()),
      GoRoute(path: '/inspection/today-summary', builder: (c, s) => const TodaySummaryPage()),

      // ========== 考勤 ==========
      GoRoute(path: '/inspection/attendance', builder: (c, s) => const AttendancePage()),
      GoRoute(path: '/inspection/attendance/overtime', builder: (c, s) => const AttendancePage(isOvertime: true)),
      GoRoute(path: '/inspection/attendance-report', builder: (c, s) => const AttendanceReportPage()),
      GoRoute(path: '/inspection/work-hours', builder: (c, s) => const WorkHoursPage()),

      // ========== 车辆档案 ==========
      GoRoute(path: '/vehicle-archive/list', builder: (c, s) => const ArchiveListPage()),
      GoRoute(
        name: 'vehicle-archive-detail',
        path: '/vehicle-archive/detail/:plateNumber',
        builder: (c, s) => ArchiveDetailPage(plateNumber: s.pathParameters['plateNumber']!),
      ),
      GoRoute(path: '/vehicle-archive/add', builder: (c, s) => const ArchiveFormPage()),
      GoRoute(
        name: 'vehicle-archive-edit',
        path: '/vehicle-archive/edit/:plateNumber',
        builder: (c, s) => ArchiveFormPage(plateNumber: s.pathParameters['plateNumber']!),
      ),

      // ========== 天气 ==========
      GoRoute(path: '/weather', builder: (c, s) => const WeatherDashboardPage()),
      GoRoute(path: '/weather/warnings', builder: (c, s) => const WeatherWarningListPage()),
      GoRoute(path: '/weather/warning/:warningId', builder: (c, s) {
        final warningId = int.parse(s.pathParameters['warningId']!);
        return WeatherWarningDetailPage(warningId: warningId);
      }),
      GoRoute(path: '/weather/zones', builder: (c, s) => const WeatherZonePage()),
      GoRoute(path: '/weather/thresholds', builder: (c, s) => const WeatherThresholdPage()),

      // ========== 配件 ==========
      GoRoute(path: '/inspection/parts', builder: (c, s) => const PartsListPage()),
      GoRoute(path: '/inspection/parts/requisition/:partId', builder: (c, s) {
        final partId = int.parse(s.pathParameters['partId']!);
        return PartsRequisitionPage(partId: partId);
      }),
      GoRoute(path: '/inspection/parts/management', builder: (c, s) => const PartsManagementPage()),

      // ========== 工程机械 ==========
      GoRoute(path: '/machinery/apply', builder: (c, s) => const ApplyPage()),
      GoRoute(path: '/machinery/my-applications', builder: (c, s) => const MyApplicationsPage()),
      GoRoute(path: '/machinery/cost-stats', builder: (c, s) => const CostStatsPage()),
      GoRoute(path: '/machinery/detail/:appId', builder: (c, s) {
        final appId = int.parse(s.pathParameters['appId']!);
        return ApplicationDetailPage(appId: appId);
      }),
      GoRoute(path: '/machinery/pending', builder: (c, s) => const PendingListPage()),
      GoRoute(path: '/machinery/all', builder: (c, s) => const AllApplicationsPage()),
      GoRoute(path: '/machinery/assign/:appId', builder: (c, s) {
        final appId = int.parse(s.pathParameters['appId']!);
        return AssignPage(appId: appId);
      }),
      GoRoute(path: '/machinery/dispatched', builder: (c, s) => const DispatchedPage()),
      GoRoute(path: '/machinery/dispatch-export', builder: (c, s) => const DispatchExportPage()),
      GoRoute(path: '/machinery/kanban', builder: (c, s) => const DispatchKanbanPage()),
      GoRoute(path: '/machinery/assigned-history', builder: (c, s) => const AssignedHistoryPage()),
      GoRoute(path: '/machinery/application-analysis', builder: (c, s) => const ApplicationAnalysisPage()),
      GoRoute(path: '/machinery/driver-tasks', builder: (c, s) => const DriverTasksPage()),

      // ========== 单车核算 ==========
      GoRoute(path: '/ledger', builder: (c, s) => const LedgerHomePage()),
      GoRoute(path: '/ledger/monthly', builder: (c, s) => const MonthlyLedgerPage()),
      GoRoute(path: '/ledger/kpi', builder: (c, s) => const KpiRankingPage()),
      GoRoute(path: '/ledger/thresholds', builder: (c, s) => const ThresholdConfigPage()),
      GoRoute(path: '/ledger/maintenance', builder: (c, s) => const MaintenancePage()),
      GoRoute(path: '/ledger/budget', builder: (c, s) => const BudgetPage()),
      GoRoute(path: '/ledger/budget/config', builder: (c, s) => const BudgetConfigPage()),
      GoRoute(path: '/ledger/budget/import', builder: (c, s) => const BudgetImportPage()),

      // ========== 管理后台 ==========
      // /admin removed — leader dashboard now directly links to sub-pages
      GoRoute(path: '/admin/users', builder: (c, s) => const UserManagementPage()),
      // /admin/vehicles removed — use /vehicle-archive/list instead
      GoRoute(path: '/admin/shops', builder: (c, s) => const ShopManagementPage()),
      GoRoute(path: '/admin/export', builder: (c, s) => const ExportPage()),
      GoRoute(path: '/admin/backup', builder: (c, s) => const BackupPage()),
      GoRoute(path: '/admin/config', builder: (c, s) => const ConfigPage()),
      GoRoute(path: '/admin/quiz', builder: (c, s) => const QuizPage()),  // 所有角色可访问

      // ========== 开发工具 ==========
      GoRoute(path: '/dev/export-icon', builder: (c, s) => const IconExportPage()),
    ],
  );
  globalRouter = router;
  return router;
});
