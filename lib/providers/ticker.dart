import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 仪表盘每15秒自动刷新
final dashboardTickerProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 15), (i) => i);
});

/// 列表页每30秒自动刷新
final listTickerProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (i) => i);
});
