import 'dart:convert';
import 'dart:html' as html;

/// Web implementation: uses browser-native HttpRequest → blob → download.
Future<String?> downloadFileWeb(
  String apiBase,
  String path,
  Map<String, dynamic> body,
  String filename,
  String? token,
) async {
  final resp = await html.HttpRequest.request(
    '$apiBase$path',
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
  return null; // Web returns null — browser handles download
}
