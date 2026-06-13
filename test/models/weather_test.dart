import 'package:flutter_test/flutter_test.dart';
import 'package:mine_repair_flutter/models/weather.dart';

void main() {
  group('WeatherData', () {
    test('fromJson basic', () {
      final json = {'data_type': 'temperature', 'value': 28.5};
      final w = WeatherData.fromJson(json);
      expect(w.dataType, 'temperature');
      expect(w.value, 28.5);
    });

    test('fromJson defaults', () {
      final w = WeatherData.fromJson({});
      expect(w.dataType, '');
      expect(w.value, 0.0);
    });
  });

  group('WeatherWarning', () {
    final baseJson = {
      'id': 1,
      'zone_id': 2,
      'weather_type': '暴雨',
      'level': '橙色',
      'description': '预计未来6小时有大到暴雨',
      'zone_name': '矿区A区',
      'status': 'active',
    };

    test('fromJson basic', () {
      final w = WeatherWarning.fromJson(baseJson);
      expect(w.id, 1);
      expect(w.weatherType, '暴雨');
      expect(w.level, '橙色');
      expect(w.description, '预计未来6小时有大到暴雨');
      expect(w.zoneName, '矿区A区');
      expect(w.status, 'active');
    });

    test('default status is active', () {
      final w = WeatherWarning.fromJson({'id': 1, 'zone_id': 2, 'weather_type': '风', 'level': '蓝色'});
      expect(w.status, 'active');
    });
  });

  group('WeatherZone', () {
    test('fromJson basic', () {
      final json = {
        'id': 1,
        'zone_name': '矿区A区',
        'zone_code': 'ZONE_A',
        'description': '主矿坑区域',
        'latitude': 35.12,
        'longitude': 118.56,
        'status': 1,
      };
      final z = WeatherZone.fromJson(json);
      expect(z.id, 1);
      expect(z.zoneName, '矿区A区');
      expect(z.zoneCode, 'ZONE_A');
      expect(z.latitude, 35.12);
      expect(z.longitude, 118.56);
      expect(z.status, 1);
    });

    test('fromJson defaults', () {
      final z = WeatherZone.fromJson({'id': 1, 'zone_name': '', 'zone_code': ''});
      expect(z.latitude, 0);
      expect(z.longitude, 0);
      expect(z.status, 1);
    });
  });
}
