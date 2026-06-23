import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Android/iOS/桌面 — 跳过 SSL 证书严格校验
HttpClientAdapter createAdapter() {
  return IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    },
  );
}
