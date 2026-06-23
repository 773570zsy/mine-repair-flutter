import 'jpush_service_io.dart' if (dart.library.html) 'jpush_service_web.dart';

/// JPush 推送服务统一入口
///
/// - Android/iOS: jpush_flutter SDK（极光推送原生通道）
/// - Web: 存根（JPush 不支持浏览器推送）
///
/// 用法:
/// ```dart
/// await JpushService().init();           // 注册推送
/// await JpushService().setAlias(phone);  // 绑定用户（登录后）
/// await JpushService().stop();           // 停止推送（登出时）
/// ```
class JpushService {
  static final JpushService _instance = JpushService._();
  factory JpushService() => _instance;
  JpushService._();

  final _impl = createJPushService();

  String? get registrationId => _impl.registrationId;

  /// 通知点击回调（App 入口注册，用于页面跳转）
  NotificationTapCallback? get onNotificationTap => _impl.onNotificationTap;
  set onNotificationTap(NotificationTapCallback? cb) => _impl.onNotificationTap = cb;

  /// 初始化极光推送
  Future<void> init() => _impl.init();

  /// 绑定用户别名（登录成功后调用）
  /// [uniqueId] — 用户唯一标识（手机号 或 userId）
  Future<void> setAlias(String uniqueId) => _impl.setAlias(uniqueId);

  /// 解绑别名
  Future<void> deleteAlias() => _impl.deleteAlias();

  /// 设置标签（角色分类）
  Future<void> addTags(List<String> tags) => _impl.addTags(tags);

  /// 移除标签
  Future<void> removeTags(List<String> tags) => _impl.removeTags(tags);

  /// 清空标签
  Future<void> cleanTags() => _impl.cleanTags();

  /// 停止接收推送（登出时调用）
  Future<void> stop() => _impl.stop();

  /// 恢复接收推送（登录时调用）
  Future<void> resume() => _impl.resume();
}
