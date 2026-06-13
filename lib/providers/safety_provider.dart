import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assessment.dart';
import '../services/safety_service.dart';

/// 考核通报列表
final assessmentListProvider = FutureProvider<List<Assessment>>((ref) async {
  final service = SafetyService();
  return service.getAssessments();
});

/// 我的考核（被考核人视角）
final myAssessmentsProvider = FutureProvider<List<Assessment>>((ref) async {
  final service = SafetyService();
  return service.getAssessments(my: true);
});

/// 考核详情
final assessmentDetailProvider =
    FutureProvider.family<Assessment?, int>((ref, id) async {
  final service = SafetyService();
  return service.getAssessmentDetail(id);
});

/// 全部用户列表（用于选择整改人/被考核人）
final allUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = SafetyService();
  return service.getAllUsers();
});

/// 考核操作状态
class SafetyActionsState {
  final bool loading;
  final String? error;
  final String? successMsg;

  const SafetyActionsState({this.loading = false, this.error, this.successMsg});

  SafetyActionsState copyWith({bool? loading, String? error, String? successMsg}) {
    return SafetyActionsState(
      loading: loading ?? this.loading,
      error: error,
      successMsg: successMsg,
    );
  }
}

class SafetyActionsNotifier extends StateNotifier<SafetyActionsState> {
  final SafetyService _service = SafetyService();
  final Ref _ref;

  SafetyActionsNotifier(this._ref) : super(const SafetyActionsState());

  Future<void> issueAssessment({
    required int targetId,
    required String title,
    String content = '',
    String assessType = '通报',
    List<String>? photos,
    String? assessDate,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _service.issueAssessment(
        targetId: targetId,
        title: title,
        content: content,
        assessType: assessType,
        photos: photos,
        assessDate: assessDate,
      );
      state = state.copyWith(loading: false, successMsg: '通报已下发');
      _ref.invalidate(assessmentListProvider);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMsg: null);
  }
}

final safetyActionsProvider =
    StateNotifierProvider<SafetyActionsNotifier, SafetyActionsState>((ref) {
  return SafetyActionsNotifier(ref);
});
