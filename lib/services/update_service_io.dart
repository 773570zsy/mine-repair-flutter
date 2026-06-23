import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'update_info.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  bool _checking = false;
  String? _downloadTaskId;

  late final Dio _dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10),
    ));
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
    return dio;
  }

  /// 初始化下载回调
  void initDownloadCallback(void Function(double progress, int status) onUpdate) {
    FlutterDownloader.registerCallback((id, status, progress) {
      if (id == _downloadTaskId) {
        onUpdate(progress / 100.0, status);
      }
    });
  }

  /// 检查一次（防止重复触发）
  Future<UpdateInfo?> checkOnce() async {
    if (_checking) return null;
    _checking = true;
    try {
      return await checkUpdate();
    } finally {
      _checking = false;
    }
  }

  /// 检查是否有新版本
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await _dio.get('${ApiConfig.baseUrl}/api/app-version');
      if (response.data['code'] != 200) return null;

      final remote = UpdateInfo.fromJson(response.data['data']);
      final local = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(local.buildNumber) ?? 0;

      if (remote.versionCode > localCode) return remote;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 后台下载 APK（使用系统 DownloadManager，息屏/切后台不中断）
  Future<String> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final savedDir = dir.path;

    // 清理旧文件
    final oldFile = File('$savedDir/update.apk');
    if (await oldFile.exists()) await oldFile.delete();

    // 使用系统 DownloadManager 下载
    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: savedDir,
      fileName: 'update.apk',
      showNotification: true,
      openFileFromNotification: false,
    );
    _downloadTaskId = taskId;
    onProgress(0.0);
    return '$savedDir/update.apk';
  }

  /// 安装 APK
  Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
  }
}
