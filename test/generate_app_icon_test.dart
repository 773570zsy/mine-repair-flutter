import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_repair_flutter/utils/app_icon_painter.dart';

/// Generates `assets/icon/app_icon_1024.png` from the [AppIconPainter].
///
/// Run:  flutter test test/generate_app_icon_test.dart
///
/// This uses the Flutter engine's software rasterizer (available in the
/// test environment) to render the CustomPainter to a PNG file.
void main() {
  test('Generate 1024×1024 app icon PNG', () async {
    const size = 1024;

    // Render the CustomPainter to a Picture
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    const AppIconPainter().paint(canvas, ui.Size(size.toDouble(), size.toDouble()));
    final picture = recorder.endRecording();

    // Convert Picture to Image, then to PNG bytes
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(byteData, isNotNull, reason: 'PNG encoding produced null');
    final bytes = byteData!.buffer.asUint8List();

    // Write to assets/icon/
    final dir = Directory('assets/icon');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/app_icon_1024.png');
    await file.writeAsBytes(bytes);

    // Verify
    expect(await file.exists(), isTrue);
    final fileSize = await file.length();
    // ignore: avoid_print
    print('✅ App icon generated: ${file.absolute.path} ($fileSize bytes)');
  });
}
