import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'file_saver.dart';
import '../config/api_config.dart';

// Conditional imports: web gets the real dart:html impl, others get stub
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_io.dart';

/// 跨平台 XLSX 下载服务
/// - Web: 浏览器原生 HttpRequest（无 CORS 问题，已验证可用）
/// - 移动端/桌面: Dio + path_provider
class DownloadService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  DownloadService._();

  static final DownloadService _instance = DownloadService._();
  static DownloadService get instance => _instance;

  void init(Dio dio) {
    _dio = dio;
  }

  /// 下载 XLSX 文件，返回保存路径（Web 返回 null，触发浏览器下载）
  /// [shareAfterSave] — 保存后自动弹出系统分享面板（默认 true）
  Future<String?> downloadXlsx(
    String path,
    Map<String, dynamic> body,
    String filename, {
    bool shareAfterSave = true,
  }) async {
    if (kIsWeb) {
      return _downloadWeb(path, body, filename);
    }
    return _downloadMobile(path, body, filename, shareAfterSave: shareAfterSave);
  }

  /// Web 端：通过条件导入的 downloadFileWeb 函数（实际来自 download_helper_web.dart）
  Future<String?> _downloadWeb(String path, Map<String, dynamic> body, String filename) async {
    final token = await _storage.read(key: 'jwt_token');
    return downloadFileWeb(ApiConfig.apiBase, path, body, filename, token);
  }

  /// 移动端/桌面端：Dio bytes → 保存到 Downloads → 弹出分享面板
  Future<String?> _downloadMobile(String path, Map<String, dynamic> body, String filename, {bool shareAfterSave = true}) async {
    final response = await _dio.post(
      '${ApiConfig.apiBase}$path',
      data: jsonEncode(body),
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.statusCode != 200) {
      throw Exception('导出失败：服务器错误 ${response.statusCode}');
    }
    final bytes = response.data;
    if (bytes is! List<int> || bytes.isEmpty) {
      throw Exception('导出失败：服务器无数据返回');
    }
    final filePath = await FileSaver.instance.saveBytes(bytes, filename);
    if (filePath != null && shareAfterSave) {
      // 异步分享，不阻塞返回
      FileSaver.instance.shareFile(filePath, subject: filename);
    }
    return filePath;
  }
}
