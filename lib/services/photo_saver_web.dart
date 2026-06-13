// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'photo_saver.dart';

/// Web 端照片保存：优先触发浏览器下载，跨域失败时降级打开新标签
class PhotoSaverWeb implements PhotoSaver {
  @override
  Future<String?> savePhoto(String imageUrl, [String? filename]) async {
    final name = filename ?? imageUrl.split('/').last.split('?').first;
    try {
      // 尝试 fetch blob → 触发下载（同源可直接下载）
      final resp = await html.HttpRequest.request(
        imageUrl,
        method: 'GET',
        responseType: 'blob',
      );
      final blob = resp.response as html.Blob?;
      if (blob != null && blob.size > 0) {
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', name)
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);
        return null;
      }
    } catch (_) {
      // 跨域或网络问题，降级打开新标签
      html.window.open(imageUrl, '_blank');
    }
    return null;
  }
}

/// 工厂函数（供条件导入使用）
PhotoSaver createPhotoSaver() => PhotoSaverWeb();
