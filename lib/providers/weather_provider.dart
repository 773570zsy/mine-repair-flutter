import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather.dart';
import '../services/weather_service.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) => WeatherService());

/// 仪表盘
final weatherDashboardProvider = FutureProvider<WeatherDashboard?>((ref) {
  return ref.read(weatherServiceProvider).getDashboard();
});

/// 预警列表
final weatherWarningsProvider = FutureProvider<List<WeatherWarning>>((ref) {
  return ref.read(weatherServiceProvider).getWarnings();
});

/// 活跃预警
final activeWarningsProvider = FutureProvider<List<WeatherWarning>>((ref) {
  return ref.read(weatherServiceProvider).getActiveWarnings();
});

/// 区域列表
final weatherZonesProvider = FutureProvider<List<WeatherZone>>((ref) {
  return ref.read(weatherServiceProvider).getZones();
});

/// 阈值列表
final weatherThresholdsProvider = FutureProvider<List<WeatherThreshold>>((ref) {
  return ref.read(weatherServiceProvider).getThresholds();
});

/// Actions
class WeatherActions extends StateNotifier<AsyncValue<void>> {
  final WeatherService _service;
  final Ref _ref;

  WeatherActions(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<void> acknowledgeWarning(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.acknowledgeWarning(id);
      _ref.invalidate(weatherDashboardProvider);
      _ref.invalidate(weatherWarningsProvider);
    });
  }

  Future<void> resolveWarning(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.resolveWarning(id);
      _ref.invalidate(weatherDashboardProvider);
      _ref.invalidate(weatherWarningsProvider);
    });
  }

  Future<void> createZone(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.createZone(data);
      _ref.invalidate(weatherZonesProvider);
    });
  }

  Future<void> updateZone(int id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.updateZone(id, data);
      _ref.invalidate(weatherZonesProvider);
    });
  }

  Future<void> deleteZone(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.deleteZone(id);
      _ref.invalidate(weatherZonesProvider);
    });
  }

  Future<void> saveThreshold(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.saveThreshold(data);
      _ref.invalidate(weatherThresholdsProvider);
    });
  }

  Future<void> updateThreshold(int id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.updateThreshold(id, data);
      _ref.invalidate(weatherThresholdsProvider);
    });
  }

  Future<void> deleteThreshold(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.deleteThreshold(id);
      _ref.invalidate(weatherThresholdsProvider);
    });
  }
}

final weatherActionsProvider = StateNotifierProvider<WeatherActions, AsyncValue<void>>((ref) {
  final service = ref.read(weatherServiceProvider);
  return WeatherActions(service, ref);
});
