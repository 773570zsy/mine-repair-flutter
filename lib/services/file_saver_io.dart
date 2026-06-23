import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'file_saver.dart';

/// 移动端/桌面端文件保存：优先保存到 Downloads 公共目录，方便用户查找
class FileSaverIO implements FileSaver {
  @override
  Future<String?> saveBytes(List<int> bytes, String filename) async {
    try {
      // 优先保存到 Downloads 目录（Android/iOS/Windows 均可访问）
      Directory? dir = await getDownloadsDirectory();
      // Fallback：某些设备可能没有 Downloads 目录
      dir ??= await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// 分享文件（调用系统分享面板）
  @override
  Future<bool> shareFile(String filePath, {String? subject}) async {
    try {
      final file = XFile(filePath);
      await Share.shareXFiles([file], subject: subject);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 工厂函数（供条件导入使用）
FileSaver createFileSaver() => FileSaverIO();
