import 'dart:convert';

class Hazard {
  final int id;
  final String hazardNo;
  final int reporterId;
  final String? reporterName;
  final int? responsibleId;
  final String? responsibleName;
  final int? verifiedBy;
  final String? verifierName;
  final String location;
  final String description;
  final String severity; // 低, 一般, 高, 紧急
  final String status; // reported, assigned, rectifying, completed, verified
  final String deadline;
  final List<String>? photosBefore;
  final List<String>? photosAfter;
  final String? rectifyDesc;
  final String? rejectReason;
  final String createdAt;
  final String updatedAt;

  Hazard({
    required this.id,
    required this.hazardNo,
    required this.reporterId,
    this.reporterName,
    this.responsibleId,
    this.responsibleName,
    this.verifiedBy,
    this.verifierName,
    required this.location,
    required this.description,
    required this.severity,
    required this.status,
    required this.deadline,
    this.photosBefore,
    this.photosAfter,
    this.rectifyDesc,
    this.rejectReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Hazard.fromJson(Map<String, dynamic> json) {
    return Hazard(
      id: json['id'] ?? 0,
      hazardNo: json['hazard_no'] ?? '',
      reporterId: json['reporter_id'] ?? 0,
      reporterName: json['reporter_name'],
      responsibleId: json['responsible_id'],
      responsibleName: json['responsible_name'],
      verifiedBy: json['verified_by'],
      verifierName: json['verifier_name'],
      location: json['location'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? '一般',
      status: json['status'] ?? 'reported',
      deadline: json['deadline'] ?? '',
      photosBefore: _parsePhotos(json['photos_before']),
      photosAfter: _parsePhotos(json['photos_after']),
      rectifyDesc: json['rectify_desc'],
      rejectReason: json['reject_reason'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
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

  /// Status display label
  String get statusLabel {
    const map = {
      'reported': '待指派',
      'assigned': '已指派',
      'rectifying': '整改中',
      'completed': '待确认',
      'verified': '已闭环',
    };
    return map[status] ?? status;
  }

  /// Whether current user can assign (safety_officer/admin on reported status)
  bool get canAssign => status == 'reported';

  /// Whether assigned user can rectify
  bool get canRectify => status == 'assigned' || status == 'rectifying';

  /// Whether safety officer can verify/reject
  bool get canVerify => status == 'completed';

  bool get isClosed => status == 'verified';
}
