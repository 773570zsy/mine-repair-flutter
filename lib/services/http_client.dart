import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// API 响应模型
class ApiResponse<T> {
  final int code;
  final String? msg;
  final T? data;
  final Map<String, dynamic> rawData;

  ApiResponse({required this.code, this.msg, this.data, this.rawData = const {}});
  bool get isSuccess => code == 200;
}

/// Dio HTTP 客户端（单例）- JWT 拦截器 + 401 自动跳转
class HttpClient {
  static HttpClient? _instance;
  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  void Function()? onUnauthorized;

  HttpClient._() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 自动附加 JWT Token
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          onUnauthorized?.call();
        }
        // 从后端 JSON 提取中文错误信息，替换英文 DioException
        final data = error.response?.data;
        if (data is Map) {
          final msg = data['msg'] as String?;
          if (msg != null && msg.isNotEmpty) {
            handler.next(DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: msg,
              message: msg,
            ));
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  factory HttpClient() {
    _instance ??= HttpClient._();
    return _instance!;
  }

  /// 获取 Dio 实例（供 DownloadService 等使用）
  static Dio get sharedDio => (HttpClient()).dio;

  String? get token => _token;

  /// 初始化token（从存储读取，或登录后设置）
  Future<void> initToken(String? t) async {
    _token = t;
    if (t != null) {
      await _storage.write(key: 'jwt_token', value: t);
    }
  }

  /// 从安全存储加载 token
  Future<String?> loadToken() async {
    _token = await _storage.read(key: 'jwt_token');
    return _token;
  }

  /// 清除 token（登出）
  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'jwt_token');
  }

  Map<String, dynamic> _parseResp(dynamic responseData) {
    return responseData is Map<String, dynamic> ? responseData : {};
  }

  /// GET 请求
  Future<ApiResponse<dynamic>> get(String path, {Map<String, dynamic>? queryParams}) async {
    final resp = await dio.get(path, queryParameters: queryParams);
    final raw = _parseResp(resp.data);
    return ApiResponse(
      code: raw['code'] as int,
      msg: raw['msg'] as String?,
      data: raw['data'],
      rawData: raw,
    );
  }

  /// GET 请求 — 返回原始文本（用于 CSV 导出等非 JSON 响应）
  Future<String> getText(String path, {Map<String, dynamic>? queryParams}) async {
    final resp = await dio.get(path,
      queryParameters: queryParams,
      options: Options(responseType: ResponseType.plain),
    );
    return resp.data.toString();
  }

  /// POST 请求
  Future<ApiResponse<dynamic>> post(String path, {dynamic data}) async {
    final resp = await dio.post(path, data: data);
    final raw = _parseResp(resp.data);
    return ApiResponse(
      code: raw['code'] as int,
      msg: raw['msg'] as String?,
      data: raw['data'],
      rawData: raw,
    );
  }

  /// PUT 请求
  Future<ApiResponse<dynamic>> put(String path, {dynamic data}) async {
    final resp = await dio.put(path, data: data);
    final raw = _parseResp(resp.data);
    return ApiResponse(
      code: raw['code'] as int,
      msg: raw['msg'] as String?,
      data: raw['data'],
      rawData: raw,
    );
  }

  /// DELETE 请求
  Future<ApiResponse<dynamic>> delete(String path) async {
    final resp = await dio.delete(path);
    final raw = _parseResp(resp.data);
    return ApiResponse(
      code: raw['code'] as int,
      msg: raw['msg'] as String?,
      data: raw['data'],
      rawData: raw,
    );
  }

  /// 文件上传（字节，跨平台兼容 Web + 移动端）
  Future<ApiResponse<dynamic>> uploadBytes(
    String path, Uint8List bytes, String filename, String fieldName,
  ) async {
    final formData = FormData.fromMap({
      fieldName: MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await dio.post(path, data: formData);
    return ApiResponse(
      code: resp.data['code'] as int,
      msg: resp.data['msg'] as String?,
      data: resp.data['data'],
    );
  }

  /// 多文件上传（字节列表）
  Future<ApiResponse<dynamic>> uploadMultipleBytes(
    String path, List<Uint8List> bytesList, List<String> filenames, String fieldName,
  ) async {
    final files = <MultipartFile>[];
    for (var i = 0; i < bytesList.length; i++) {
      files.add(MultipartFile.fromBytes(bytesList[i], filename: filenames[i]));
    }
    final formData = FormData.fromMap({fieldName: files});
    final resp = await dio.post(path, data: formData);
    return ApiResponse(
      code: resp.data['code'] as int,
      msg: resp.data['msg'] as String?,
      data: resp.data['data'],
    );
  }
}
