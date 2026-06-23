import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/routes.dart' show globalRouter;
import 'services/file_saver.dart';
import 'services/photo_saver.dart';
import 'services/http_client.dart';
import 'services/download_service.dart';
import 'services/notification_service.dart';
import 'services/jpush_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';
// 条件导入：Web用dart:html，移动端用dart:io
import 'services/file_saver_web.dart' if (dart.library.io) 'services/file_saver_io.dart' as saver;
import 'services/photo_saver_web.dart' if (dart.library.io) 'services/photo_saver_io.dart' as ps;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FileSaver.init(saver.createFileSaver());
  PhotoSaver.init(ps.createPhotoSaver());
  DownloadService.instance.init(HttpClient.sharedDio);

  // 初始化后台下载器
  FlutterDownloader.initialize(debug: false);

  // 初始化本地通知服务（Web: 浏览器Notification API; Native: 存根）
  NotificationService().init();

  // 初始化极光推送（仅 Android/iOS，Web 为 no-op）
  JpushService().init();

  // 注册通知点击跳转
  JpushService().onNotificationTap = (type, orderId) {
    final router = globalRouter;
    if (router == null) {
      debugPrint('[JPush] globalRouter is null, cannot navigate');
      return;
    }
    String? route = _routeForNotification(type, orderId);
    if (route != null) {
      debugPrint('[JPush] navigating to: $route');
      router.push(route);
    }
  };

  runApp(
    const ProviderScope(
      child: MineRepairApp(),
    ),
  );
}

/// 根据通知类型返回跳转路由
String? _routeForNotification(String type, String? orderId) {
  switch (type) {
    // 维修
    case 'new_order':
      return orderId != null ? '/repair/detail/$orderId' : '/repair/shop-orders';
    case 'new_external_order':
      return orderId != null ? '/external-repair/detail/$orderId' : '/external-repair/shop-orders';
    case 'quote_pending':
      return orderId != null ? '/repair/detail/$orderId' : '/repair/pending-approval';
    case 'quote_approved':
    case 'quote_rejected':
    case 'repair_completed':
    case 'urgent':
      return orderId != null ? '/repair/detail/$orderId' : null;
    // 隐患
    case 'new_hazard':
      return '/hazard/list';
    // 工程机械派车
    case 'new_machinery':
      return '/machinery/pending';
    case 'machinery_dispatch': // 驾驶员收到新任务
      return orderId != null ? '/machinery/detail/$orderId' : '/machinery/driver-tasks';
    case 'machinery_assigned': // 申请人收到已指派
    case 'machinery_completed': // 用车到期自动完成
    case 'machinery_revoked': // 指派被撤销
      return orderId != null ? '/machinery/detail/$orderId' : '/machinery/my-applications';
    default:
      return null;
  }
}
