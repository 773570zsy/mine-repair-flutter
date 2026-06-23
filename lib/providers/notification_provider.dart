import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_item.dart';
import '../services/http_client.dart';

// ==================== HTTP Service ====================

class NotificationApi {
  final HttpClient _client = HttpClient();

  Future<NotificationListResult> getNotifications() async {
    final resp = await _client.get('/notifications');
    if (!resp.isSuccess) throw Exception(resp.msg ?? '获取通知失败');
    final data = resp.data as Map<String, dynamic>? ?? {};
    final list = (data['list'] as List<dynamic>?)
        ?.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return NotificationListResult(
      list: list,
      unread: data['unread'] as int? ?? 0,
    );
  }

  Future<void> markRead(int id) async {
    await _client.put('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.put('/notifications/read-all');
  }
}

final notificationApiProvider = Provider<NotificationApi>((_) => NotificationApi());

// ==================== 通知列表 Provider ====================

final notificationListProvider = FutureProvider<NotificationListResult>((ref) {
  return ref.read(notificationApiProvider).getNotifications();
});

// ==================== 未读数轮询 ====================

/// 轮询间隔（通知需要快速响应）
const _pollInterval = Duration(seconds: 5);

class UnreadCountNotifier extends StateNotifier<AsyncValue<int>> {
  final NotificationApi _api;
  Timer? _timer;
  int _lastUnread = 0;
  bool _disposed = false;

  UnreadCountNotifier(this._api) : super(const AsyncValue.loading()) {
    _fetch();
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final result = await _api.getNotifications();
      final newUnread = result.unread;

      if (_disposed) return;

      // 检测新通知（用于触发 OS 弹窗等）
      if (_lastUnread > 0 && newUnread > _lastUnread) {
        debugPrint('[UnreadNotifier] New notifications detected: $newUnread (was $_lastUnread)');
      }

      _lastUnread = newUnread;
      state = AsyncValue.data(newUnread);
    } catch (e, st) {
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  /// 手动刷新（操作后调用）
  Future<void> refresh() => _fetch();

  /// 标记已读后更新计数
  void decrement() {
    state.whenData((count) {
      if (count > 0) state = AsyncValue.data(count - 1);
    });
  }

  /// 全部已读
  void clear() {
    _lastUnread = 0;
    state = const AsyncValue.data(0);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

final unreadCountProvider =
    StateNotifierProvider<UnreadCountNotifier, AsyncValue<int>>((ref) {
  return UnreadCountNotifier(ref.read(notificationApiProvider));
});

// ==================== 通知操作 ====================

class NotificationActions extends StateNotifier<AsyncValue<void>> {
  final NotificationApi _api;

  NotificationActions(this._api) : super(const AsyncValue.data(null));

  Future<void> markRead(int id) async {
    try {
      await _api.markRead(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllRead() async {
    state = const AsyncValue.loading();
    try {
      await _api.markAllRead();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationActionsProvider =
    StateNotifierProvider<NotificationActions, AsyncValue<void>>((ref) {
  return NotificationActions(ref.read(notificationApiProvider));
});
