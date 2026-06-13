import '../models/assessment.dart';
import 'http_client.dart';

class SafetyService {
  final HttpClient _client = HttpClient();

  /// 下发考核通报
  Future<Map<String, dynamic>> issueAssessment({
    required int targetId,
    required String title,
    String content = '',
    String assessType = '通报',
    List<String>? photos,
    String? assessDate,
  }) async {
    final res = await _client.post('/safety/assessment', data: {
      'target_id': targetId,
      'title': title,
      'content': content,
      'assess_type': assessType,
      'photos': photos ?? [],
      if (assessDate != null && assessDate.isNotEmpty) 'assess_date': assessDate,
    });
    if (!res.isSuccess) throw Exception(res.msg ?? '下发失败');
    return res.data as Map<String, dynamic>;
  }

  /// 考核通报列表
  Future<List<Assessment>> getAssessments({bool my = false}) async {
    final params = <String, dynamic>{};
    if (my) params['my'] = '1';
    final res = await _client.get('/safety/assessments', queryParams: params.isNotEmpty ? params : null);
    final data = res.data;
    if (data == null) return [];
    return (data as List).map((e) => Assessment.fromJson(e)).toList();
  }

  /// 考核详情
  Future<Assessment?> getAssessmentDetail(int id) async {
    final res = await _client.get('/safety/assessment/$id');
    final data = res.data;
    if (data == null) return null;
    return Assessment.fromJson(data);
  }

  /// 获取所有用户（用于选择整改人/被考核人）
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final res = await _client.get('/inspection/all-users');
    final data = res.data;
    if (data == null) return [];
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
