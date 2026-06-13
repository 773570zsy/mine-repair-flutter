import '../models/weather.dart';
import 'http_client.dart';

class WeatherService {
  final HttpClient _client = HttpClient();

  /// 仪表盘
  Future<WeatherDashboard?> getDashboard() async {
    final resp = await _client.get('/weather/dashboard');
    if (resp.isSuccess && resp.data != null) {
      return WeatherDashboard.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 预警列表
  Future<List<WeatherWarning>> getWarnings({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final resp = await _client.get('/weather/warnings', queryParams: params);
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as List).map((e) => WeatherWarning.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// 活跃预警
  Future<List<WeatherWarning>> getActiveWarnings() async {
    final resp = await _client.get('/weather/warnings/active');
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as List).map((e) => WeatherWarning.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// 预警详情
  Future<WeatherWarning?> getWarningDetail(int id) async {
    final resp = await _client.get('/weather/warnings/$id');
    if (resp.isSuccess && resp.data != null) {
      return WeatherWarning.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 确认预警
  Future<void> acknowledgeWarning(int id) async {
    await _client.post('/weather/warnings/$id/acknowledge');
  }

  /// 解除预警
  Future<void> resolveWarning(int id) async {
    await _client.post('/weather/warnings/$id/resolve');
  }

  // ==================== 区域管理（admin） ====================

  Future<List<WeatherZone>> getZones() async {
    final resp = await _client.get('/weather/zones');
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as List).map((e) => WeatherZone.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> createZone(Map<String, dynamic> data) async {
    await _client.post('/weather/zones', data: data);
  }

  Future<void> updateZone(int id, Map<String, dynamic> data) async {
    await _client.put('/weather/zones/$id', data: data);
  }

  Future<void> deleteZone(int id) async {
    await _client.delete('/weather/zones/$id');
  }

  // ==================== 阈值管理（admin） ====================

  Future<List<WeatherThreshold>> getThresholds({String? weatherType}) async {
    final params = <String, dynamic>{};
    if (weatherType != null) params['weather_type'] = weatherType;
    final resp = await _client.get('/weather/thresholds', queryParams: params);
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as List).map((e) => WeatherThreshold.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> saveThreshold(Map<String, dynamic> data) async {
    await _client.post('/weather/thresholds', data: data);
  }

  Future<void> updateThreshold(int id, Map<String, dynamic> data) async {
    await _client.put('/weather/thresholds/$id', data: data);
  }

  Future<void> deleteThreshold(int id) async {
    await _client.delete('/weather/thresholds/$id');
  }

  // ==================== 本地天气 ====================

  /// 获取本地天气（传入GPS坐标，后端翻译+缓存）
  Future<Map<String, dynamic>?> getLocalWeather(double lat, double lon) async {
    final resp = await _client.get('/weather/local', queryParams: {
      'lat': lat.toString(),
      'lon': lon.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }
}
