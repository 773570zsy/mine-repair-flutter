import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web 通知服务 — 使用浏览器 Notification API
class WebNotificationService {
  bool _webGranted = false;

  Future<void> init() async {
    try {
      final permission = await html.Notification.requestPermission();
      _webGranted = permission == 'granted';
      debugPrint('[NotificationService] Web permission: $_webGranted');
    } catch (e) {
      debugPrint('[NotificationService] Web init failed: $e');
    }
  }

  Future<void> show({required String title, required String body, String? tag}) async {
    try {
      if (_webGranted) {
        html.Notification(title, body: body, tag: tag);
      }
    } catch (e) {
      debugPrint('[NotificationService] Web show failed: $e');
    }
  }
}

/// 工厂函数（供条件导入使用）
WebNotificationService createNotificationService() => WebNotificationService();
