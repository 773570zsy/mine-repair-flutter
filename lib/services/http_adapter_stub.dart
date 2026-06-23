import 'package:dio/dio.dart';

/// Web 平台 — 无 SSL 问题，不处理
HttpClientAdapter? createAdapter() => null;
