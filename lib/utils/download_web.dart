import 'dart:html' as html;

/// Web 平台：通过 Blob + AnchorElement 触发下载
void downloadBlob(String text, String filename) {
  final blob = html.Blob([text], 'text/plain;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
