import '../models/hazard.dart';
import 'http_client.dart';

class HazardService {
  final HttpClient _client = HttpClient();

  /// 上报隐患
  Future<Map<String, dynamic>> reportHazard({
    required String description,
    String location = '',
    String severity = '一般',
    int? responsibleId,
    String deadline = '',
    List<String>? photosBefore,
  }) async {
    final res = await _client.post('/hazards/report', data: {
      'location': location,
      'description': description,
      'severity': severity,
      'responsible_id': responsibleId,
      'deadline': deadline,
      'photos_before': photosBefore ?? [],
    });
    if (!res.isSuccess) throw Exception(res.msg ?? '上报失败');
    return res.data as Map<String, dynamic>;
  }

  /// 隐患列表
  Future<List<Hazard>> getHazardList({String? status, bool my = false}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (my) params['my'] = '1';
    final res = await _client.get('/hazards/list', queryParams: params.isNotEmpty ? params : null);
    final data = res.data;
    if (data == null) return [];
    return (data as List).map((e) => Hazard.fromJson(e)).toList();
  }

  /// 隐患详情
  Future<Hazard?> getHazardDetail(int id) async {
    final res = await _client.get('/hazards/detail/$id');
    final data = res.data;
    if (data == null) return null;
    return Hazard.fromJson(data);
  }

  /// 指派整改人
  Future<void> assignHazard(int id, int responsibleId, String deadline) async {
    final res = await _client.post('/hazards/assign/$id', data: {
      'responsible_id': responsibleId,
      'deadline': deadline,
    });
    if (!res.isSuccess) throw Exception(res.msg ?? '指派失败');
  }

  /// 提交整改
  Future<void> rectifyHazard(int id, List<String> photosAfter, String rectifyDesc) async {
    final res = await _client.post('/hazards/rectify/$id', data: {
      'photos_after': photosAfter,
      'rectify_desc': rectifyDesc,
    });
    if (!res.isSuccess) throw Exception(res.msg ?? '提交失败');
  }

  /// 确认验收
  Future<void> verifyHazard(int id) async {
    final res = await _client.post('/hazards/verify/$id');
    if (!res.isSuccess) throw Exception(res.msg ?? '验收失败');
  }

  /// 驳回整改
  Future<void> rejectRectify(int id, String reason) async {
    final res = await _client.post('/hazards/reject-rectify/$id', data: {
      'reject_reason': reason,
    });
    if (!res.isSuccess) throw Exception(res.msg ?? '驳回失败');
  }

  /// 到期提醒
  Future<Map<String, dynamic>> getAlerts() async {
    final res = await _client.get('/hazards/alerts');
    return (res.data as Map<String, dynamic>?) ?? {};
  }
}
