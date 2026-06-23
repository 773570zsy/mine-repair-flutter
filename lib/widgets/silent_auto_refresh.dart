import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 静默自动刷新包装器
///
/// 每隔 [intervalSeconds] 秒自动执行 [onRefresh]，无转圈、无闪屏，用户无感。
///
/// 用法：
/// ```dart
/// SilentAutoRefresh(
///   intervalSeconds: 20,
///   onRefresh: (ref) {
///     ref.invalidate(myDataProvider);
///   },
///   child: SingleChildScrollView(...),
/// )
/// ```
class SilentAutoRefresh extends ConsumerStatefulWidget {
  final Widget child;
  final int intervalSeconds;
  final void Function(WidgetRef ref) onRefresh;

  const SilentAutoRefresh({
    super.key,
    required this.child,
    this.intervalSeconds = 20,
    required this.onRefresh,
  });

  @override
  ConsumerState<SilentAutoRefresh> createState() => _SilentAutoRefreshState();
}

class _SilentAutoRefreshState extends ConsumerState<SilentAutoRefresh> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: widget.intervalSeconds), (_) {
      if (!mounted) return;
      widget.onRefresh(ref);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
