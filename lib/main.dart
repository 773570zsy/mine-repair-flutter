import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/file_saver.dart';
import 'services/photo_saver.dart';
import 'services/http_client.dart';
import 'services/download_service.dart';
import 'services/notification_service.dart';
// 条件导入：Web用dart:html，移动端用dart:io
import 'services/file_saver_web.dart' if (dart.library.io) 'services/file_saver_io.dart' as saver;
import 'services/photo_saver_web.dart' if (dart.library.io) 'services/photo_saver_io.dart' as ps;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FileSaver.init(saver.createFileSaver());
  PhotoSaver.init(ps.createPhotoSaver());
  DownloadService.instance.init(HttpClient.sharedDio);

  // 初始化本地通知服务（非Web平台）
  NotificationService().init();

  runApp(
    const ProviderScope(
      child: MineRepairApp(),
    ),
  );
}
