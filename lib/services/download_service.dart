// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'file_saver.dart';
import '../config/api_config.dart';

/// 跨平台 XLSX 下载服务
/// - Web: 浏览器原生 HttpRequest（无 CORS 问题，已验证可用）
/// - 移动端: Dio + path_provider
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
  Future<String?> downloadXlsx(
    String path,
    Map<String, dynamic> body,
    String filename,
  ) async {
    if (kIsWeb) {
      return _downloadWeb(path, body, filename);
    }
    return _downloadMobile(path, body, filename);
  }

  /// Web 端：浏览器原生 HttpRequest → blob → 触发下载
  Future<String?> _downloadWeb(String path, Map<String, dynamic> body, String filename) async {
    final token = await _storage.read(key: 'jwt_token');
    final resp = await html.HttpRequest.request(
      '${ApiConfig.apiBase}$path',
      method: 'POST',
      requestHeaders: {
        'Authorization': 'Bearer ${token ?? ''}',
        'Content-Type': 'application/json',
      },
      sendData: jsonEncode(body),
      responseType: 'blob',
    );
    final blob = resp.response as html.Blob?;
    if (blob == null) throw Exception('导出失败：服务器无数据返回');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    Future.delayed(const Duration(milliseconds: 200), () {
      html.Url.revokeObjectUrl(url);
    });
    return null;
  }

  /// 移动端：Dio bytes → path_provider 保存
  Future<String?> _downloadMobile(String path, Map<String, dynamic> body, String filename) async {
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
    return FileSaver.instance.saveBytes(bytes, filename);
  }
}
