import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'photo_saver.dart';

/// 移动端/桌面端照片保存：独立 Dio（SSL 绕过，无 API 拦截器）→ Downloads 公共目录
class PhotoSaverIO implements PhotoSaver {
  late final Dio _dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
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

  @override
  Future<String?> savePhoto(String imageUrl, [String? filename]) async {
    try {
      final response = await _dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes is! List<int> || bytes.isEmpty) {
        throw Exception('下载的文件为空');
      }

      final name = filename ?? imageUrl.split('/').last.split('?').first;
      // 优先保存到 Downloads 公共目录，方便用户在文件管理器查看
      Directory? dir = await getDownloadsDirectory();
      dir ??= await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);

      // 保存成功后弹出系统分享面板，方便用户直接查看/发送
      try {
        await Share.shareXFiles([XFile(file.path)], subject: name);
      } catch (_) { /* 分享失败不影响保存 */ }

      return file.path;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.message ?? '下载失败');
      }
      rethrow;
    }
  }
}

/// 工厂函数（供条件导入使用）
PhotoSaver createPhotoSaver() => PhotoSaverIO();
