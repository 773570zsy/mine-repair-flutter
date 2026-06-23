import 'package:flutter/foundation.dart';

/// 通知点击回调签名（与 jpush_service_io.dart 保持一致）
typedef NotificationTapCallback = void Function(String type, String? orderId);

/// JPush Web 存根（极光推送不支持 Web 平台）
class JPushServiceWeb {
  String? get registrationId => null;

  /// 通知点击回调（Web 平台无推送，始终为 null）
  NotificationTapCallback? onNotificationTap;

  Future<void> init() async {
    debugPrint('[JPush] Web platform — no-op');
  }

  Future<void> setAlias(String uniqueId) async {}
  Future<void> deleteAlias() async {}
  Future<void> addTags(List<String> tags) async {}
  Future<void> removeTags(List<String> tags) async {}
  Future<void> cleanTags() async {}
  Future<void> stop() async {}
  Future<void> resume() async {}
}

JPushServiceWeb createJPushService() => JPushServiceWeb();
