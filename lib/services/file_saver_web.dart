import 'dart:html' as html;
import 'file_saver.dart';

/// Web 端文件保存：通过浏览器 blob + AnchorElement 下载
class FileSaverWeb implements FileSaver {
  @override
  Future<String?> saveBytes(List<int> bytes, String filename) async {
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    Future.delayed(const Duration(milliseconds: 200), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
    return null;
  }
}

/// 工厂函数（供条件导入使用）
FileSaver createFileSaver() => FileSaverWeb();
