import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'app_icon_painter.dart';
import 'save_icon_stub.dart'
    if (dart.library.html) 'save_icon_web.dart'
    if (dart.library.io) 'save_icon_io.dart';

/// Renders [AppIconPainter] to PNG bytes via [ui.PictureRecorder].
///
/// Must be called within a Flutter engine context (widget, test, etc.).
Future<Uint8List> renderAppIconToPng({int size = 1024}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
  );
  const AppIconPainter().paint(canvas, Size(size.toDouble(), size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw Exception('Failed to encode app icon to PNG');
  }
  return byteData.buffer.asUint8List();
}

// ── Dev-only export page ──
// Navigate to this page via debug menu or direct route, then tap
// "Download" to save the 1024×1024 source PNG for flutter_launcher_icons.

class IconExportPage extends StatefulWidget {
  const IconExportPage({super.key});

  @override
  State<IconExportPage> createState() => _IconExportPageState();
}

class _IconExportPageState extends State<IconExportPage> {
  final _repaintKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final obj = _repaintKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        _toast('Error: RenderRepaintBoundary not found');
        if (mounted) setState(() => _saving = false);
        return;
      }
      final image = await obj.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        _toast('Error: PNG encode failed');
        if (mounted) setState(() => _saving = false);
        return;
      }
      await saveIconBytes(
        data.buffer.asUint8List(),
        'app_icon_1024.png',
      );
      _toast('Saved! Place this file as your flutter_launcher_icons source.');
    } catch (e) {
      _toast('Error: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D23),
      appBar: AppBar(title: const Text('Export App Icon')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('1024×1024  source',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            RepaintBoundary(
              key: _repaintKey,
              child: const SizedBox.square(
                dimension: 1024,
                child: CustomPaint(painter: AppIconPainter()),
              ),
            ),
            const SizedBox(height: 24),
            const Text('256×256', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            const SizedBox.square(
              dimension: 256,
              child: CustomPaint(painter: AppIconPainter()),
            ),
            const SizedBox(height: 16),
            const Text('64×64', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            const SizedBox.square(
              dimension: 64,
              child: CustomPaint(painter: AppIconPainter()),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(_saving ? 'Saving...' : 'Download 1024×1024 PNG'),
            ),
          ],
        ),
      ),
    );
  }
}
