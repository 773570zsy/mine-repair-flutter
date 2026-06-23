import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hazard.dart';
import '../services/hazard_service.dart';
import 'ticker.dart';

/// 隐患列表（支持状态筛选，30秒自动刷新）
final hazardListProvider =
    FutureProvider.family<List<Hazard>, String?>((ref, status) async {
  ref.watch(listTickerProvider);
  final service = HazardService();
  return service.getHazardList(status: status);
});

/// 我的隐患（整改人视角，30秒自动刷新）
final myHazardsProvider = FutureProvider<List<Hazard>>((ref) async {
  ref.watch(listTickerProvider);
  final service = HazardService();
  return service.getHazardList(my: true);
});

/// 隐患详情
final hazardDetailProvider =
    FutureProvider.family<Hazard?, int>((ref, id) async {
  final service = HazardService();
  return service.getHazardDetail(id);
});

/// 隐患到期提醒
final hazardAlertsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = HazardService();
  return service.getAlerts();
});

/// 隐患操作（StateNotifier 管理异步操作状态）
class HazardActionsState {
  final bool loading;
  final String? error;
  final String? successMsg;

  const HazardActionsState({this.loading = false, this.error, this.successMsg});

  HazardActionsState copyWith({bool? loading, String? error, String? successMsg}) {
    return HazardActionsState(
      loading: loading ?? this.loading,
      error: error,
      successMsg: successMsg,
    );
  }
}

class HazardActionsNotifier extends StateNotifier<HazardActionsState> {
  final HazardService _service = HazardService();
  final Ref _ref;

  HazardActionsNotifier(this._ref) : super(const HazardActionsState());

  Future<void> reportHazard({
    required String description,
    String location = '',
    String severity = '一般',
    int? responsibleId,
    String deadline = '',
    List<String>? photosBefore,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _service.reportHazard(
        description: description,
        location: location,
        severity: severity,
        responsibleId: responsibleId,
        deadline: deadline,
        photosBefore: photosBefore,
      );
      state = state.copyWith(loading: false, successMsg: '上报成功');
      _ref.invalidate(hazardListProvider);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> assignHazard(int id, int responsibleId, String deadline) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _service.assignHazard(id, responsibleId, deadline);
      state = state.copyWith(loading: false, successMsg: '已指派');
      _ref.invalidate(hazardListProvider);
      _ref.invalidate(hazardDetailProvider(id));
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> rectifyHazard(int id, List<String> photosAfter, String rectifyDesc) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _service.rectifyHazard(id, photosAfter, rectifyDesc);
      state = state.copyWith(loading: false, successMsg: '整改已提交');
      _ref.invalidate(hazardListProvider);
      _ref.invalidate(hazardDetailProvider(id));
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> verifyHazard(int id) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _service.verifyHazard(id);
      state = state.copyWith(loading: false, successMsg: '已验收通过');
      _ref.invalidate(hazardListProvider);
      _ref.invalidate(hazardDetailProvider(id));
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> rejectRectify(int id, String reason) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _service.rejectRectify(id, reason);
      state = state.copyWith(loading: false, successMsg: '已驳回');
      _ref.invalidate(hazardListProvider);
      _ref.invalidate(hazardDetailProvider(id));
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMsg: null);
  }
}

final hazardActionsProvider =
    StateNotifierProvider<HazardActionsNotifier, HazardActionsState>((ref) {
  return HazardActionsNotifier(ref);
});
