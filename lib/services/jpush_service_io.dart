import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 通知点击回调签名
typedef NotificationTapCallback = void Function(String type, String? orderId);

/// JPush 原生实现（Android / iOS）
/// 通过 MethodChannel 与原生层通信，不依赖 jpush_flutter 包
class JPushServiceImpl {
  static const _channel = MethodChannel('com.julong.mine_repair_flutter/jpush');

  String? _registrationId;
  bool _initialized = false;

  /// 通知点击回调（App 入口注册，用于页面跳转）
  NotificationTapCallback? onNotificationTap;

  String? get registrationId => _registrationId;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // 注册接收 Android 原生层的 onOpenNotification 调用
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onOpenNotification') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          if (args != null) {
            final type = args['type'] as String? ?? '';
            final orderId = args['order_id'] as String?;
            debugPrint('[JPush] notification tapped: type=$type, order_id=$orderId');
            onNotificationTap?.call(type, orderId);
          }
        }
      });

      await _channel.invokeMethod('setup');
      // Android 13+ 请求通知权限（低版本/已授权直接跳过）
      try {
        await _channel.invokeMethod('requestNotificationPermission');
      } catch (e) {
        debugPrint('[JPush] notification permission request failed: $e');
      }
      try {
        _registrationId = await _channel.invokeMethod<String>('getRegistrationID');
        debugPrint('[JPush] registrationId: $_registrationId');
      } catch (e) {
        debugPrint('[JPush] getRegistrationID failed: $e');
      }
      _initialized = true;
      debugPrint('[JPush] initialized');
    } catch (e) {
      debugPrint('[JPush] init failed: $e');
    }
  }

  /// 设置用户别名（用于定向推送）
  /// [uniqueId] — 用户唯一标识（如手机号）
  Future<void> setAlias(String uniqueId) async {
    if (!_initialized) await init();
    try {
      await _channel.invokeMethod('setAlias', {'alias': uniqueId});
      debugPrint('[JPush] setAlias: $uniqueId');
    } catch (e) {
      debugPrint('[JPush] setAlias failed: $e');
    }
  }

  /// 删除别名
  Future<void> deleteAlias() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('deleteAlias');
      debugPrint('[JPush] alias deleted');
    } catch (e) {
      debugPrint('[JPush] deleteAlias failed: $e');
    }
  }

  /// 添加标签（如角色）
  Future<void> addTags(List<String> tags) async {
    if (!_initialized) await init();
    if (tags.isEmpty) return;
    try {
      await _channel.invokeMethod('addTags', {'tags': tags});
      debugPrint('[JPush] addTags: $tags');
    } catch (e) {
      debugPrint('[JPush] addTags failed: $e');
    }
  }

  /// 移除标签
  Future<void> removeTags(List<String> tags) async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('removeTags', {'tags': tags});
      debugPrint('[JPush] removeTags: $tags');
    } catch (e) {
      debugPrint('[JPush] removeTags failed: $e');
    }
  }

  /// 清空所有标签
  Future<void> cleanTags() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('cleanTags');
      debugPrint('[JPush] tags cleaned');
    } catch (e) {
      debugPrint('[JPush] cleanTags failed: $e');
    }
  }

  /// 停止推送（用户登出时调用）
  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('stopPush');
      debugPrint('[JPush] stopped');
    } catch (e) {
      debugPrint('[JPush] stop failed: $e');
    }
  }

  /// 恢复推送（用户登录时调用）
  Future<void> resume() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('resumePush');
      debugPrint('[JPush] resumed');
    } catch (e) {
      debugPrint('[JPush] resume failed: $e');
    }
  }
}

JPushServiceImpl createJPushService() => JPushServiceImpl();
