import 'package:flutter/foundation.dart';

/// 通知服务接口
abstract class NotificationServiceImpl {
  Future<void> init();
  Future<void> show({required String title, required String body, String? tag});
}

/// 存根实现（非 Web 平台 — 安装 flutter_local_notifications 后替换）
class StubNotificationService implements NotificationServiceImpl {
  @override
  Future<void> init() async {
    debugPrint('[NotificationService] Stub — install flutter_local_notifications for native notifications');
  }

  @override
  Future<void> show({required String title, required String body, String? tag}) async {
    debugPrint('[NotificationService] Stub show: $title');
  }
}

NotificationServiceImpl createNotificationService() => StubNotificationService();
