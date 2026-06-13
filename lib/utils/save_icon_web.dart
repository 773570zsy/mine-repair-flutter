// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download for [bytes] as [filename].
Future<void> saveIconBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  // Clean up after a short delay so the download can start
  Future.delayed(const Duration(milliseconds: 200), () {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  });
}
