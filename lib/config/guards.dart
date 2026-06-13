import '../models/user.dart';

/// 检查用户角色是否有权访问某路由（admin 拥有所有权限）
bool hasRoleAccess(String? role, String requiredRole) {
  if (role == null) return false;
  if (role == 'admin') return true;
  return role == requiredRole;
}

/// 检查用户是否属于给定的角色列表
bool hasAnyRole(String? role, List<String> roles) {
  if (role == null) return false;
  if (role == 'admin') return true;
  return roles.contains(role);
}

/// 根据用户角色和路径返回重定向目标，null 表示允许通过
String? roleRouteGuard(User user, String loc) {
  final role = user.role;

  // 驾驶员专属 — 维修
  if ((loc == '/repair/report' || loc == '/repair/my-orders') &&
      !hasRoleAccess(role, 'driver')) {
    return '/home';
  }
  // 修理厂专属
  if ((loc == '/repair/pending-accept' ||
          loc == '/repair/shop-orders' ||
          loc.startsWith('/repair/submit-quote') ||
          loc.startsWith('/repair/update-progress')) &&
      !hasRoleAccess(role, 'repair_shop')) {
    return '/home';
  }
  // 领导/管理员专属
  if ((loc == '/repair/pending-approval' ||
          loc == '/repair/all-orders') &&
      !hasRoleAccess(role, 'leader') && !hasRoleAccess(role, 'admin')) {
    return '/home';
  }
  // 外部报修 — external_repair/applicant/driver 可报修和看本人
  if ((loc == '/external-repair/report' || loc == '/external-repair/my-requests' || loc == '/external-repair/home') &&
      !hasAnyRole(role, ['external_repair', 'applicant', 'driver'])) {
    return '/home';
  }
  // 外部报修 — 修理厂
  if ((loc == '/external-repair/pending-accept' || loc == '/external-repair/shop-orders') &&
      !hasRoleAccess(role, 'repair_shop')) {
    return '/home';
  }
  // 外部报修 — 待审批（报修人+领导+管理员）
  if (loc == '/external-repair/pending-approval' &&
      !hasAnyRole(role, ['external_repair', 'applicant', 'driver', 'leader', 'admin'])) {
    return '/home';
  }
  // 外部报修 — 全部工单（领导+管理员）
  if (loc == '/external-repair/all-orders' &&
      !hasAnyRole(role, ['leader', 'admin'])) {
    return '/home';
  }
  // 安全员/领导专属
  if ((loc == '/hazard/list' ||
          loc == '/hazard/report' ||
          loc == '/safety/assessment/list' ||
          loc == '/safety/assessment/issue') &&
      !hasAnyRole(role, ['safety_officer', 'leader'])) {
    return '/home';
  }
  // 车辆档案编辑 — admin/dispatcher 专属
  if ((loc == '/vehicle-archive/add' ||
          loc.startsWith('/vehicle-archive/edit')) &&
      !hasAnyRole(role, ['admin', 'dispatcher'])) {
    return '/vehicle-archive/list';
  }
  // 驾驶员专属 — 点检/考勤/配件领用
  if ((loc == '/inspection/morning-check' ||
          loc == '/inspection/evening-check' ||
          loc == '/inspection/my-records' ||
          loc == '/inspection/attendance' ||
          loc.startsWith('/inspection/parts/requisition')) &&
      !hasRoleAccess(role, 'driver')) {
    return '/home';
  }
  // 管理员/领导专属 — 点检概况/报表/配件管理/工时统计
  if ((loc == '/inspection/all-records' ||
          loc == '/inspection/today-summary' ||
          loc == '/inspection/attendance-report' ||
          loc == '/inspection/work-hours' ||
          loc == '/inspection/parts/management') &&
      !hasAnyRole(role, ['leader', 'admin'])) {
    return '/home';
  }
  // 申请人专属 — 工程机械申请
  if ((loc == '/machinery/apply' ||
          loc == '/machinery/my-applications' ||
          loc == '/machinery/cost-stats') &&
      !hasRoleAccess(role, 'applicant')) {
    return '/home';
  }
  // 调度员/管理员/领导专属 — 工程机械指派
  if ((loc == '/machinery/kanban' ||
          loc == '/machinery/pending' ||
          loc == '/machinery/all' ||
          loc.startsWith('/machinery/assign') ||
          loc == '/machinery/dispatched') &&
      !hasAnyRole(role, ['dispatcher', 'admin', 'leader'])) {
    return '/home';
  }
  // 驾驶员专属 — 派车任务
  if ((loc == '/machinery/driver-tasks') &&
      !hasRoleAccess(role, 'driver')) {
    return '/home';
  }
  // 管理员/领导专属 — 单车核算
  if (loc.startsWith('/ledger') &&
      !hasAnyRole(role, ['admin', 'leader'])) {
    return '/home';
  }
  // 管理员专属 — 管理后台
  // 例外：每日一测所有角色可访问；导出/备份/配置 管理员+领导可访问
  if (loc.startsWith('/admin') && loc != '/admin/quiz') {
    if (loc == '/admin/export' || loc == '/admin/backup' || loc == '/admin/config') {
      if (!hasAnyRole(role, ['admin', 'leader'])) return '/home';
    } else {
      if (!hasRoleAccess(role, 'admin')) return '/home';
    }
  }

  return null; // 允许通过
}
