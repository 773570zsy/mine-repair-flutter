/// API 配置 - 根据环境切换
class ApiConfig {
  /// 生产服务器
  static const String baseUrl = 'https://jlkydds.cn';

  /// 本地开发
  // static const String baseUrl = 'http://localhost:3000';

  /// API 前缀
  static const String apiPrefix = '/api';

  /// 完整 API 地址
  static String get apiBase => '$baseUrl$apiPrefix';

  /// 上传文件基础 URL
  static String get uploadBase => '$baseUrl/uploads';

  /// 拼接完整文件 URL
  static String fileUrl(String relativePath) {
    if (relativePath.startsWith('http')) return relativePath;
    if (relativePath.startsWith('/')) return '$baseUrl$relativePath';
    return '$uploadBase/$relativePath';
  }
}
