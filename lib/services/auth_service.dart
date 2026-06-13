import '../models/user.dart';
import 'http_client.dart';

class AuthService {
  final HttpClient _client = HttpClient();

  /// 登录
  /// 返回 {token, user, bindings, department}
  Future<LoginResult?> login(String phone, String password) async {
    final resp = await _client.post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });

    if (!resp.isSuccess || resp.data == null) {
      throw Exception(resp.msg ?? '登录失败');
    }

    final data = resp.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);

    // 绑定信息
    final bindings = (data['bindings'] as List<dynamic>?)
        ?.map((b) => UserBinding.fromJson(b as Map<String, dynamic>))
        .toList() ?? [];

    // 保存 token
    await _client.initToken(token);

    return LoginResult(
      token: token,
      user: user,
      bindings: bindings,
      department: data['department'] as Map<String, dynamic>?,
    );
  }

  /// 获取当前用户信息
  Future<User?> getUserInfo() async {
    final resp = await _client.get('/auth/userinfo');
    if (!resp.isSuccess || resp.data == null) return null;
    return User.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 修改密码
  Future<void> changePassword(String oldPwd, String newPwd) async {
    final resp = await _client.post('/admin/change-password', data: {
      'old_pwd': oldPwd,
      'new_pwd': newPwd,
    });
    if (!resp.isSuccess) {
      throw Exception(resp.msg ?? '修改失败');
    }
  }

  /// 登出
  Future<void> logout() async {
    await _client.clearToken();
  }
}

class LoginResult {
  final String token;
  final User user;
  final List<UserBinding> bindings;
  final Map<String, dynamic>? department;

  LoginResult({
    required this.token,
    required this.user,
    required this.bindings,
    this.department,
  });
}
