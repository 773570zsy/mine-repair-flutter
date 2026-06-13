import '../models/maintenance.dart';
import 'http_client.dart';

class MaintenanceService {
  final HttpClient _client = HttpClient();

  /// 保养状态列表
  Future<List<MaintenanceStatus>> getStatusList() async {
    final resp = await _client.get('/maintenance/list');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取保养列表失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MaintenanceStatus.fromJson(v as Map<String, dynamic>)).toList();
  }

  /// 记录保养
  Future<String> recordMaintenance({
    required int vehicleId,
    required String maintenanceDate,
    double? currentHours,
    int? currentKm,
    String? maintenanceType,
    String? description,
    double? cost,
    List<Map<String, dynamic>>? partsInfo,
    String? operatorName,
    String? remark,
  }) async {
    final resp = await _client.post('/maintenance/record', data: {
      'vehicle_id': vehicleId,
      'maintenance_date': maintenanceDate,
      'current_hours': currentHours ?? 0,
      'current_km': currentKm ?? 0,
      'maintenance_type': maintenanceType ?? 'regular',
      'description': description ?? '',
      'cost': cost ?? 0,
      'parts_info': partsInfo ?? [],
      'operator_name': operatorName ?? '',
      'remark': remark ?? '',
    });
    if (!resp.isSuccess) throw Exception(resp.msg ?? '记录失败');
    return resp.msg ?? '保存成功';
  }

  /// 某车保养历史
  Future<List<MaintenanceRecord>> getRecords(int vehicleId) async {
    final resp = await _client.get('/maintenance/records/$vehicleId');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取保养记录失败');
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((v) => MaintenanceRecord.fromJson(v as Map<String, dynamic>)).toList();
  }
}
