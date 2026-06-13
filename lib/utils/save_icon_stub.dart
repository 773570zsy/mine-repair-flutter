import 'dart:typed_data';

/// No-op stub for platforms without file-system or HTML access.
Future<void> saveIconBytes(Uint8List bytes, String filename) async {
  // Silently no-op on unsupported platforms.
}
