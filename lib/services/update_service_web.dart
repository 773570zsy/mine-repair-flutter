/// Web 端在线更新服务 — 仅支持版本检查（APK下载/安装不适用于Web）
library update_service_web;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';
import 'update_info.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  bool _checking = false;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<UpdateInfo?> checkOnce() async {
    if (_checking) return null;
    _checking = true;
    try {
      return await checkUpdate();
    } finally {
      _checking = false;
    }
  }

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

  /// Web 端不支持 APK 下载
  Future<String> downloadApk(String url, void Function(double) onProgress) async {
    throw UnsupportedError('APK download is not supported on Web');
  }

  /// Web 端不支持 APK 安装
  Future<void> installApk(String filePath) async {
    throw UnsupportedError('APK install is not supported on Web');
  }
}
