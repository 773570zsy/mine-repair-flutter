import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';
import '../services/jpush_service.dart';

/// 认证状态
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;
  final String? token;
  final String? error;
  final List<UserBinding> bindings;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.token,
    this.error,
    this.bindings = const [],
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    User? user,
    String? token,
    String? error,
    List<UserBinding>? bindings,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      token: token ?? this.token,
      error: error,
      bindings: bindings ?? this.bindings,
    );
  }
}

/// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();
  final HttpClient _client = HttpClient();

  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _tryAutoLogin();
  }

  /// 尝试自动登录（从存储读取 token）
  Future<void> _tryAutoLogin() async {
    final token = await _client.loadToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }

    // 用 token 获取用户信息验证是否有效
    await _client.initToken(token);
    try {
      final user = await _authService.getUserInfo();
      if (user != null) {
        state = AuthState(
          isLoggedIn: true,
          user: user,
          token: token,
          isLoading: false,
        );
        // 自动登录后恢复推送
        _onLoginSuccess(user);
      } else {
        await _client.clearToken();
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      await _client.clearToken();
      state = state.copyWith(isLoading: false);
    }
  }

  /// 登录
  Future<void> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.login(phone, password);
      if (result == null) {
        state = state.copyWith(isLoading: false, error: '登录失败');
        return;
      }
      state = AuthState(
        isLoggedIn: true,
        user: result.user,
        token: result.token,
        bindings: result.bindings,
        isLoading: false,
      );
      // 登录成功后绑定推送别名 + 角色标签
      _onLoginSuccess(result.user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 登出
  Future<void> logout() async {
    // 登出前解绑推送
    _onLogout();
    await _authService.logout();
    state = const AuthState();
  }

  // ===== JPush 联动 =====

  /// 登录 / 自动登录成功后：绑定别名 + 角色标签
  void _onLoginSuccess(User user) {
    final jpush = JpushService();
    jpush.resume();
    // 用手机号作别名，后端可定向推送给特定用户
    if (user.phone.isNotEmpty) {
      jpush.setAlias(user.phone);
    }
    // 用角色作标签，后端可按角色群推
    if (user.role.isNotEmpty) {
      jpush.addTags(['role_${user.role}']);
    }
  }

  /// 登出时：停止推送 + 清空绑定
  void _onLogout() {
    final jpush = JpushService();
    jpush.cleanTags();
    jpush.deleteAlias();
    jpush.stop();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
