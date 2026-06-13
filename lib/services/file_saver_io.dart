import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'file_saver.dart';

/// 移动端/桌面端文件保存：写入临时目录，返回路径
class FileSaverIO implements FileSaver {
  @override
  Future<String?> saveBytes(List<int> bytes, String filename) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

/// 工厂函数（供条件导入使用）
FileSaver createFileSaver() => FileSaverIO();
