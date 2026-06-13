import 'notification_service_io.dart'
    if (dart.library.html) 'notification_service_web.dart';

/// 通知服务统一入口
///
/// - Web: 浏览器 Notification API（弹窗需用户授权）
/// - 移动/桌面: 当前为存根，安装 flutter_local_notifications 后填入 native 实现
///
/// TODO 安装原生通知:
///   1. pubspec.yaml 加 flutter_local_notifications: ^17.2.0
///   2. flutter pub get
///   3. 在 notification_service_io.dart 中实现 AndroidNotification + WindowsNotification
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _impl = createNotificationService();

  Future<void> init() => _impl.init();

  Future<void> show({required String title, required String body, String? tag}) =>
      _impl.show(title: title, body: body, tag: tag);

  // ===== 快捷方法 =====

  Future<void> showNewOrder(String orderNo, String vehicle) async {
    await show(title: '新报修工单', body: '$orderNo：$vehicle 等待接单', tag: orderNo);
  }

  Future<void> showApprovalResult(String orderNo, bool approved, {String? reason}) async {
    await show(
      title: approved ? '报价已通过' : '报价被驳回',
      body: approved
          ? '$orderNo 报价审批通过，请开始维修'
          : '$orderNo 报价被驳回：${reason ?? "请重新报价"}',
      tag: orderNo,
    );
  }

  Future<void> showUrgent(String orderNo) async {
    await show(title: '工单加急', body: '$orderNo 已标记为加急，请优先处理！', tag: orderNo);
  }

  Future<void> showRepairCompleted(String orderNo) async {
    await show(title: '维修完成', body: '$orderNo 已完工，请确认验收', tag: orderNo);
  }
}
