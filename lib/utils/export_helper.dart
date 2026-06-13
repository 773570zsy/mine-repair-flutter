import 'package:flutter/foundation.dart' show kIsWeb;
import 'download_stub.dart' if (dart.library.html) 'download_web.dart' as dl;

/// 下载/导出文本文件：Web 端触发浏览器下载，手机端无操作（走弹窗复制）
void downloadTextFile(String text, String filename) {
  if (kIsWeb) {
    dl.downloadBlob(text, filename);
  }
}
