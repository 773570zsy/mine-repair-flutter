/// 版本更新信息数据类（IO/Web 共享，无平台依赖）
class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String changelog;
  final bool forceUpdate;

  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      versionCode: json['versionCode'] ?? 0,
      versionName: json['versionName'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      changelog: json['changelog'] ?? '',
      forceUpdate: json['forceUpdate'] ?? false,
    );
  }
}
