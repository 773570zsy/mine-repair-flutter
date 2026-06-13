import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'photo_saver.dart';

/// 移动端/桌面端照片保存：Dio 下载 → app 文档目录
class PhotoSaverIO implements PhotoSaver {
  final Dio _dio = Dio();

  @override
  Future<String?> savePhoto(String imageUrl, [String? filename]) async {
    try {
      final response = await _dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes is! List<int> || bytes.isEmpty) return null;

      final name = filename ?? imageUrl.split('/').last.split('?').first;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

/// 工厂函数（供条件导入使用）
PhotoSaver createPhotoSaver() => PhotoSaverIO();
