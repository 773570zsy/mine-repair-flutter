/// 平台无关的文件保存接口
abstract class FileSaver {
  /// 保存二进制文件，返回保存路径（Web 返回 null，直接触发下载）
  Future<String?> saveBytes(List<int> bytes, String filename);

  /// 分享文件（调用系统分享面板）
  Future<bool> shareFile(String filePath, {String? subject});

  /// 单例
  static FileSaver? _instance;
  static FileSaver get instance {
    if (_instance != null) return _instance!;
    throw UnsupportedError('FileSaver not initialized. Call FileSaver.init() in main.');
  }

  static void init(FileSaver impl) {
    _instance = impl;
  }
}
