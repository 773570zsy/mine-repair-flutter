/// Stub — should never be called; real platform implementations
/// are selected via conditional imports.
Future<String?> downloadFileWeb(
  String apiBase,
  String path,
  Map<String, dynamic> body,
  String filename,
  String? token,
) async {
  throw UnsupportedError('downloadFileWeb is only supported on web platform');
}
