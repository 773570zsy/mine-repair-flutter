/// 平台无关的照片保存接口
abstract class PhotoSaver {
  /// 下载远程照片到本地，返回保存路径（Web 返回 null，触发浏览器下载/新标签）
  Future<String?> savePhoto(String imageUrl, [String? filename]);

  /// 单例
  static PhotoSaver? _instance;
  static PhotoSaver get instance {
    if (_instance != null) return _instance!;
    throw UnsupportedError('PhotoSaver not initialized. Call PhotoSaver.init() in main.');
  }

  static void init(PhotoSaver impl) {
    _instance = impl;
  }
}
