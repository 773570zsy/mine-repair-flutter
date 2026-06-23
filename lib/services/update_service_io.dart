import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'update_info.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  /// 防止重复检查
  bool _checking = false;

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

  /// 检查是否有新版本，返回 UpdateInfo 或 null
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
      return null; // 网络异常静默跳过
    }
  }

  /// 下载 APK，回调进度 0.0~1.0，返回文件路径
  Future<String> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/update.apk');
    if (await file.exists()) await file.delete();

    await _dio.download(
      url,
      file.path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );

    return file.path;
  }

  /// 打开 APK 触发系统安装
  Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
  }
}
