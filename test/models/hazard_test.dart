import 'package:flutter_test/flutter_test.dart';
import 'package:mine_repair_flutter/models/hazard.dart';

void main() {
  group('Hazard', () {
    final baseJson = {
      'id': 1,
      'hazard_no': 'HZ20260609001',
      'reporter_id': 5,
      'reporter_name': '张三',
      'responsible_id': 6,
      'responsible_name': '李四',
      'verified_by': null,
      'verifier_name': null,
      'location': '矿区A区',
      'description': '边坡有裂缝',
      'severity': '高',
      'status': 'reported',
      'deadline': '2026-06-15',
      'created_at': '2026-06-09',
      'updated_at': '2026-06-09',
    };

    test('fromJson basic parsing', () {
      final h = Hazard.fromJson(baseJson);
      expect(h.id, 1);
      expect(h.hazardNo, 'HZ20260609001');
      expect(h.location, '矿区A区');
      expect(h.severity, '高');
      expect(h.status, 'reported');
      expect(h.deadline, '2026-06-15');
      expect(h.reporterName, '张三');
    });

    test('fromJson defaults', () {
      final h = Hazard.fromJson({'id': 1});
      expect(h.location, '');
      expect(h.description, '');
      expect(h.severity, '一般');
      expect(h.status, 'reported');
    });

    test('photos_before parsed from JSON string', () {
      final json = {...baseJson, 'photos_before': '["a.jpg","b.jpg"]'};
      expect(Hazard.fromJson(json).photosBefore, ['a.jpg', 'b.jpg']);
    });

    test('photos_before parsed from List', () {
      final json = {...baseJson, 'photos_before': ['x.jpg']};
      expect(Hazard.fromJson(json).photosBefore, ['x.jpg']);
    });

    test('photos_before null/empty', () {
      expect(Hazard.fromJson({...baseJson, 'photos_before': null}).photosBefore, isNull);
    });

    test('statusLabel returns correct labels', () {
      expect(_hazardWith('reported').statusLabel, '待指派');
      expect(_hazardWith('assigned').statusLabel, '已指派');
      expect(_hazardWith('rectifying').statusLabel, '整改中');
      expect(_hazardWith('completed').statusLabel, '待确认');
      expect(_hazardWith('verified').statusLabel, '已闭环');
      expect(_hazardWith('unknown').statusLabel, 'unknown');
    });

    test('action permission getters', () {
      expect(_hazardWith('reported').canAssign, isTrue);
      expect(_hazardWith('reported').canRectify, isFalse);
      expect(_hazardWith('reported').canVerify, isFalse);

      expect(_hazardWith('assigned').canAssign, isFalse);
      expect(_hazardWith('assigned').canRectify, isTrue);

      expect(_hazardWith('rectifying').canRectify, isTrue);

      expect(_hazardWith('completed').canVerify, isTrue);

      expect(_hazardWith('verified').isClosed, isTrue);
      expect(_hazardWith('reported').isClosed, isFalse);
    });
  });
}

Hazard _hazardWith(String status) {
  return Hazard.fromJson({
    'id': 1,
    'location': 'test',
    'description': 'test',
    'severity': '一般',
    'status': status,
    'deadline': '2026-01-01',
    'created_at': '2026-01-01',
    'updated_at': '2026-01-01',
  });
}
