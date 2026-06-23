/// IO (mobile/desktop) implementation: no-op.
/// The real IO download logic stays in DownloadService._downloadMobile.
/// This file exists to satisfy the conditional import for non-web platforms.
Future<String?> downloadFileWeb(
  String apiBase,
  String path,
  Map<String, dynamic> body,
  String filename,
  String? token,
) async {
  // IO platforms use the _downloadMobile path in DownloadService directly,
  // so this function is never actually called on IO.
  throw UnsupportedError('Use DownloadService._downloadMobile on IO platforms');
}
