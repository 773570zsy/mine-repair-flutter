import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance.dart';
import '../services/maintenance_service.dart';

/// Service singleton
final maintenanceServiceProvider = Provider<MaintenanceService>((ref) => MaintenanceService());

/// 保养状态列表
final maintenanceStatusListProvider = FutureProvider<List<MaintenanceStatus>>((ref) {
  return ref.read(maintenanceServiceProvider).getStatusList();
});

/// 某车保养历史
final maintenanceRecordsProvider = FutureProvider.family<List<MaintenanceRecord>, int>((ref, vehicleId) {
  return ref.read(maintenanceServiceProvider).getRecords(vehicleId);
});

/// 操作
class MaintenanceActions {
  final MaintenanceService _service;

  MaintenanceActions(this._service);

  Future<String> record({
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
    return _service.recordMaintenance(
      vehicleId: vehicleId,
      maintenanceDate: maintenanceDate,
      currentHours: currentHours,
      currentKm: currentKm,
      maintenanceType: maintenanceType,
      description: description,
      cost: cost,
      partsInfo: partsInfo,
      operatorName: operatorName,
      remark: remark,
    );
  }
}

final maintenanceActionsProvider = Provider<MaintenanceActions>((ref) {
  final service = ref.read(maintenanceServiceProvider);
  return MaintenanceActions(service);
});
