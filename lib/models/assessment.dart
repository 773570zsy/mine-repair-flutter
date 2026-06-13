import 'dart:convert';

class Assessment {
  final int id;
  final String assessNo;
  final int issuerId;
  final String? issuerName;
  final int targetId;
  final String? targetName;
  final String title;
  final String content;
  final String assessType; // 表扬, 通报, 警告, 处罚
  final List<String>? photos;
  final String createdAt;

  Assessment({
    required this.id,
    required this.assessNo,
    required this.issuerId,
    this.issuerName,
    required this.targetId,
    this.targetName,
    required this.title,
    required this.content,
    required this.assessType,
    this.photos,
    required this.createdAt,
  });

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['id'] ?? 0,
      assessNo: json['assess_no'] ?? '',
      issuerId: json['issuer_id'] ?? 0,
      issuerName: json['issuer_name'],
      targetId: json['target_id'] ?? 0,
      targetName: json['target_name'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      assessType: json['assess_type'] ?? '通报',
      photos: _parsePhotos(json['photos']),
      createdAt: json['created_at'] ?? '',
    );
  }

  static List<String>? _parsePhotos(dynamic val) {
    if (val == null) return null;
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String) {
      try {
        final parsed = jsonDecode(val);
        if (parsed is List) return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
      return [val];
    }
    return null;
  }
}
