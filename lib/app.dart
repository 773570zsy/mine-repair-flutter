import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/color_constants.dart';
import 'config/routes.dart';

/// 获取平台默认中文字体（web 安全）
String? _platformFontFamily() {
  if (kIsWeb) return null; // Web 用浏览器默认字体
  if (defaultTargetPlatform == TargetPlatform.windows) return 'Microsoft YaHei';
  if (defaultTargetPlatform == TargetPlatform.macOS) return 'PingFang SC';
  return null; // Android/iOS 用系统默认
}

/// App 入口 Widget
class MineRepairApp extends ConsumerWidget {
  const MineRepairApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '总调度室综合管理系统',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.gold, brightness: Brightness.light),
        useMaterial3: true,
        fontFamily: _platformFontFamily(),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        cardColor: AppColors.surface,
        dividerColor: AppColors.border,
        fontFamily: _platformFontFamily(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
