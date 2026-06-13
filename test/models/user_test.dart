import 'package:flutter_test/flutter_test.dart';
import 'package:mine_repair_flutter/models/user.dart';

void main() {
  group('User', () {
    final testJson = {
      'id': 1,
      'name': '张三',
      'phone': '13800001111',
      'role': 'driver',
      'repair_shop_id': null,
      'department_id': 2,
      'dept_name': '运输队',
      'shop_name': null,
      'status': 1,
    };

    test('fromJson parses all fields correctly', () {
      final user = User.fromJson(testJson);
      expect(user.id, 1);
      expect(user.name, '张三');
      expect(user.phone, '13800001111');
      expect(user.role, 'driver');
      expect(user.deptName, '运输队');
      expect(user.status, 1);
    });

    test('fromJson handles missing fields with defaults', () {
      final user = User.fromJson({'id': 2, 'name': '李四', 'role': 'admin'});
      expect(user.phone, '');
      expect(user.status, 1);
      expect(user.deptName, isNull);
    });

    test('roleLabel returns correct Chinese label', () {
      expect(User.fromJson({'id': 1, 'name': 'a', 'role': 'driver'}).roleLabel, '驾驶员');
      expect(User.fromJson({'id': 2, 'name': 'b', 'role': 'repair_shop'}).roleLabel, '修理厂');
      expect(User.fromJson({'id': 3, 'name': 'c', 'role': 'leader'}).roleLabel, '科级审批');
      expect(User.fromJson({'id': 4, 'name': 'd', 'role': 'admin'}).roleLabel, '管理员');
      expect(User.fromJson({'id': 5, 'name': 'e', 'role': 'safety_officer'}).roleLabel, '安全员');
      expect(User.fromJson({'id': 6, 'name': 'f', 'role': 'dispatcher'}).roleLabel, '车辆调度员');
      expect(User.fromJson({'id': 7, 'name': 'g', 'role': 'applicant'}).roleLabel, '用车申请人');
      expect(User.fromJson({'id': 8, 'name': 'h', 'role': 'unknown'}).roleLabel, 'unknown');
    });

    test('role boolean getters work', () {
      expect(User.fromJson({'id': 1, 'name': 'a', 'role': 'driver'}).isDriver, isTrue);
      expect(User.fromJson({'id': 1, 'name': 'a', 'role': 'driver'}).isAdmin, isFalse);
      expect(User.fromJson({'id': 2, 'name': 'b', 'role': 'admin'}).isAdmin, isTrue);
      expect(User.fromJson({'id': 3, 'name': 'c', 'role': 'repair_shop'}).isRepairShop, isTrue);
      expect(User.fromJson({'id': 4, 'name': 'd', 'role': 'safety_officer'}).isSafetyOfficer, isTrue);
      expect(User.fromJson({'id': 5, 'name': 'e', 'role': 'dispatcher'}).isDispatcher, isTrue);
      expect(User.fromJson({'id': 6, 'name': 'f', 'role': 'applicant'}).isApplicant, isTrue);
      expect(User.fromJson({'id': 7, 'name': 'g', 'role': 'leader'}).isLeader, isTrue);
    });

    test('toJson produces correct map', () {
      final user = User(id: 1, name: 'test', role: 'admin');
      final json = user.toJson();
      expect(json['id'], 1);
      expect(json['name'], 'test');
      expect(json['role'], 'admin');
      expect(json['phone'], '');
    });
  });

  group('UserBinding', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 10,
        'vehicle_id': 5,
        'plate_number': '京A12345',
        'vehicle_type': '汽车吊',
      };
      final binding = UserBinding.fromJson(json);
      expect(binding.id, 10);
      expect(binding.vehicleId, 5);
      expect(binding.plateNumber, '京A12345');
      expect(binding.vehicleType, '汽车吊');
    });

    test('fromJson handles null vehicle_type', () {
      final json = {'id': 1, 'vehicle_id': 2, 'plate_number': '京B00000'};
      final binding = UserBinding.fromJson(json);
      expect(binding.vehicleType, isNull);
    });
  });
}
