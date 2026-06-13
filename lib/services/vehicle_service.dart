import '../models/vehicle.dart';
import 'http_client.dart';

class VehicleService {
  final HttpClient _client = HttpClient();

  /// 获取所有车辆列表
  Future<List<Vehicle>> getVehicles() async {
    final resp = await _client.get('/vehicles');
    if (!resp.isSuccess || resp.data == null) {
      throw Exception(resp.msg ?? '获取车辆列表失败');
    }
    final list = resp.data as List<dynamic>;
    return list
        .map((v) => Vehicle.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// 获取车辆详情（含维修历史+点检记录+绑定历史）
  Future<VehicleDetail> getVehicleDetail(int id) async {
    final resp = await _client.get('/vehicles/$id');
    if (!resp.isSuccess || resp.data == null) {
      throw Exception(resp.msg ?? '获取车辆详情失败');
    }
    final data = resp.data as Map<String, dynamic>;
    return VehicleDetail.fromJson(data);
  }
}

/// 车辆详情（含关联数据）
class VehicleDetail {
  final Vehicle vehicle;
  final List<dynamic> repairHistory;
  final List<dynamic> inspections;
  final List<dynamic> bindings;

  VehicleDetail({
    required this.vehicle,
    this.repairHistory = const [],
    this.inspections = const [],
    this.bindings = const [],
  });

  factory VehicleDetail.fromJson(Map<String, dynamic> json) {
    return VehicleDetail(
      vehicle: Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
      repairHistory: (json['repairHistory'] as List<dynamic>?) ?? [],
      inspections: (json['inspections'] as List<dynamic>?) ?? [],
      bindings: (json['bindings'] as List<dynamic>?) ?? [],
    );
  }
}
