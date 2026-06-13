/// 角色映射（与Web端一致）
const Map<String, String> roleMap = {
  'driver': '驾驶员',
  'repair_shop': '修理厂',
  'leader': '科级审批',
  'admin': '管理员',
  'safety_officer': '安全员',
  'dispatcher': '车辆调度员',
  'applicant': '工程机械申请',
  'external_repair': '外部车辆报修',
};

/// 维修状态映射
const Map<String, String> statusMap = {
  'pending_accept': '待接单',
  'pending_quote': '待报价',
  'pending_approval': '待审批',
  'approved': '已通过',
  'rejected': '已驳回',
  'repairing': '维修中',
  'completed': '待验收',
  'accepted': '已完成',
  'cancelled': '已取消',
};

/// 状态标签颜色
const Map<String, String> statusTagColor = {
  'pending_accept': '#e67e22',
  'pending_quote': '#e67e22',
  'pending_approval': '#c0392b',
  'approved': '#27ae60',
  'rejected': '#c0392b',
  'repairing': '#2ecc71',
  'completed': '#2980b9',
  'accepted': '#27ae60',
};

/// 隐患状态映射
const Map<String, String> hazardStatusMap = {
  'reported': '已上报',
  'assigned': '已指派',
  'rectifying': '整改中',
  'completed': '待验收',
  'verified': '已闭环',
};

/// 隐患严重程度
const List<String> severityLevels = ['低', '一般', '高', '紧急'];

/// 点检指标
const Map<String, String> levelMap = {'high': '高位', 'mid': '中位', 'low': '低位'};
const Map<String, String> appearMap = {'normal': '正常', 'damaged': '有损坏', 'dirty': '需清洁'};
const Map<String, String> tireMap = {'normal': '正常', 'worn': '磨损', 'damaged': '损坏'};

/// 进度操作名称
const Map<String, String> actionNameMap = {
  'accepted_order': '修理厂接单',
  'quote_submitted': '提交报价',
  'approved': '审批通过',
  'rejected': '驳回',
  'progress_update': '进度更新',
  'completed': '维修完成',
  'accepted': '验收通过',
  'urgent': '标记加急',
};

/// 通知类型图标
const Map<String, String> notifTypeIcon = {
  'hazard_assigned': '⚠',
  'hazard_completed': '✅',
  'hazard_verified': '✅',
  'hazard_rejected': '❌',
  'assessment_new': '📋',
  'quote_pending': '💰',
  'quote_approved': '✅',
  'quote_rejected': '❌',
  'new_order': '🔧',
  'order_accepted': '📦',
  'order_urgent': '⚡',
  'repair_completed': '✅',
};
