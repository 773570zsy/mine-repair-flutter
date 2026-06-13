import 'dart:io';
import 'dart:typed_data';

/// Writes [bytes] to `assets/icon/<filename>` on desktop/mobile.
Future<void> saveIconBytes(Uint8List bytes, String filename) async {
  final dir = Directory('assets/icon');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('Icon saved to ${file.absolute.path}');
}
