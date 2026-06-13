import '../models/vehicle_archive.dart';
import 'http_client.dart';

class VehicleArchiveService {
  final HttpClient _client = HttpClient();

  /// 获取档案列表（可按部门/车型筛选）
  Future<List<VehicleArchive>> getList({String? department, String? vehicleType}) async {
    final resp = await _client.get('/vehicle-archives/list', queryParams: {
      if (department != null && department.isNotEmpty) 'department': department,
      if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle_type': vehicleType,
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List;
      return list.map((e) => VehicleArchive.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// 获取所有部门列表（用于筛选下拉）
  Future<List<String>> getDepartments() async {
    final resp = await _client.get('/vehicle-archives/departments');
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  /// 获取所有车型列表（用于筛选下拉）
  Future<List<String>> getVehicleTypes() async {
    final resp = await _client.get('/vehicle-archives/vehicle-types');
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  /// 获取档案详情
  Future<VehicleArchive?> getDetail(String plateNumber) async {
    final resp = await _client.get('/vehicle-archives/$plateNumber');
    if (resp.isSuccess && resp.data != null) {
      return VehicleArchive.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 创建档案
  Future<void> create(Map<String, dynamic> data) async {
    await _client.post('/vehicle-archives', data: data);
  }

  /// 更新档案
  Future<void> update(String plateNumber, Map<String, dynamic> data) async {
    await _client.put('/vehicle-archives/$plateNumber', data: data);
  }

  /// 删除档案
  Future<void> delete(String plateNumber) async {
    await _client.delete('/vehicle-archives/$plateNumber');
  }

  /// 保养完成（工时）
  Future<void> maintenanceDone(String plateNumber) async {
    await _client.post('/vehicle-archives/$plateNumber/maintenance-done');
  }

  /// 保养完成（公里）
  Future<void> maintenanceDoneKm(String plateNumber) async {
    await _client.post('/vehicle-archives/$plateNumber/maintenance-done-km');
  }
}
