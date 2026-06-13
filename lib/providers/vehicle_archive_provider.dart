import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle_archive.dart';
import '../services/vehicle_archive_service.dart';

/// Service provider
final vehicleArchiveServiceProvider = Provider<VehicleArchiveService>((ref) => VehicleArchiveService());

/// 档案列表（支持筛选）
final vehicleArchiveListProvider = FutureProvider<List<VehicleArchive>>((ref) {
  return ref.read(vehicleArchiveServiceProvider).getList();
});

/// 列表版本号：增删改时 ++ 触发全量刷新（包括带筛选的 family provider）
final archiveListVersionProvider = StateProvider<int>((ref) => 0);

/// 档案筛选参数
class ArchiveFilter {
  final String? department;
  final String? vehicleType;
  const ArchiveFilter({this.department, this.vehicleType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ArchiveFilter && department == other.department && vehicleType == other.vehicleType;
  @override
  int get hashCode => Object.hash(department, vehicleType);
}

/// 筛选后的档案列表
final filteredArchiveListProvider = FutureProvider.family<List<VehicleArchive>, ArchiveFilter>((ref, filter) {
  ref.watch(archiveListVersionProvider); // 版本号变化时强制刷新
  return ref.read(vehicleArchiveServiceProvider).getList(
    department: filter.department,
    vehicleType: filter.vehicleType,
  );
});

/// 部门列表（筛选下拉用）
final archiveDepartmentsProvider = FutureProvider<List<String>>((ref) {
  return ref.read(vehicleArchiveServiceProvider).getDepartments();
});

/// 车型列表（筛选下拉用）
final archiveVehicleTypesProvider = FutureProvider<List<String>>((ref) {
  return ref.read(vehicleArchiveServiceProvider).getVehicleTypes();
});

/// 档案详情（按 plate_number）
final vehicleArchiveDetailProvider = FutureProvider.family<VehicleArchive?, String>((ref, plateNumber) {
  return ref.read(vehicleArchiveServiceProvider).getDetail(plateNumber);
});

/// Actions notifier
class VehicleArchiveActions extends StateNotifier<AsyncValue<void>> {
  final VehicleArchiveService _service;
  final Ref _ref;

  VehicleArchiveActions(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<void> create(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.create(data);
      _ref.read(archiveListVersionProvider.notifier).state++;
    });
  }

  Future<void> update(String plateNumber, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.update(plateNumber, data);
      _ref.read(archiveListVersionProvider.notifier).state++;
      _ref.invalidate(vehicleArchiveDetailProvider(plateNumber));
    });
  }

  Future<void> delete(String plateNumber) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.delete(plateNumber);
      _ref.read(archiveListVersionProvider.notifier).state++;
    });
  }

  Future<void> maintenanceDone(String plateNumber) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.maintenanceDone(plateNumber);
      _ref.read(archiveListVersionProvider.notifier).state++;
      _ref.invalidate(vehicleArchiveDetailProvider(plateNumber));
    });
  }

  Future<void> maintenanceDoneKm(String plateNumber) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.maintenanceDoneKm(plateNumber);
      _ref.read(archiveListVersionProvider.notifier).state++;
      _ref.invalidate(vehicleArchiveDetailProvider(plateNumber));
    });
  }
}

final vehicleArchiveActionsProvider = StateNotifierProvider<VehicleArchiveActions, AsyncValue<void>>((ref) {
  final service = ref.read(vehicleArchiveServiceProvider);
  return VehicleArchiveActions(service, ref);
});
