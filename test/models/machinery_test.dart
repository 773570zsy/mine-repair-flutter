import 'package:flutter_test/flutter_test.dart';
import 'package:mine_repair_flutter/models/machinery.dart';

void main() {
  group('MachineryApplication', () {
    final baseJson = {
      'id': 1,
      'application_no': 'MC20260609001',
      'applicant_id': 5,
      'applicant_dept': '运输队',
      'applicant_name': '张三',
      'applicant_phone': '13800001111',
      'vehicle_type': '汽车吊',
      'application_type': 'short_term',
      'scheduled_start': '2026-06-10 08:00',
      'scheduled_end': '2026-06-10 17:00',
      'work_location': '矿区A区',
      'work_purpose': '吊装设备',
      'is_hazardous': 0,
      'urgency': 'normal',
      'status': 'pending',
    };

    test('fromJson basic fields', () {
      final app = MachineryApplication.fromJson(baseJson);
      expect(app.id, 1);
      expect(app.applicationNo, 'MC20260609001');
      expect(app.vehicleType, '汽车吊');
      expect(app.applicationType, 'short_term');
      expect(app.workLocation, '矿区A区');
      expect(app.status, 'pending');
      expect(app.isHazardous, isFalse);
    });

    test('statusLabel returns correct labels', () {
      final tests = {
        'pending': '待指派',
        'assigned': '用车中',
        'in_progress': '用车中',
        'completed': '已完成',
        'early_completed': '提前结束',
        'cancelled': '已取消',
      };
      for (final e in tests.entries) {
        final app = MachineryApplication.fromJson({...baseJson, 'status': e.key});
        expect(app.statusLabel, e.value);
      }
    });

    test('urgencyLabel returns correct labels', () {
      final tests = {'normal': '普通', 'urgent': '加急', 'emergency': '紧急'};
      for (final e in tests.entries) {
        final app = MachineryApplication.fromJson({...baseJson, 'urgency': e.key});
        expect(app.urgencyLabel, e.value);
      }
    });

    test('typeLabel returns correct labels', () {
      final st = MachineryApplication.fromJson({...baseJson, 'application_type': 'short_term'});
      final lt = MachineryApplication.fromJson({...baseJson, 'application_type': 'long_term'});
      expect(st.typeLabel, '短期');
      expect(lt.typeLabel, '长期');
    });

    test('state boolean getters', () {
      expect(MachineryApplication.fromJson({...baseJson, 'status': 'pending'}).isPending, isTrue);
      expect(MachineryApplication.fromJson({...baseJson, 'status': 'assigned'}).isActive, isTrue);
      expect(MachineryApplication.fromJson({...baseJson, 'status': 'in_progress'}).isActive, isTrue);
      expect(MachineryApplication.fromJson({...baseJson, 'status': 'completed'}).isCompleted, isTrue);
      expect(MachineryApplication.fromJson({...baseJson, 'status': 'early_completed'}).isCompleted, isTrue);
      expect(MachineryApplication.fromJson({...baseJson, 'status': 'cancelled'}).isCancelled, isTrue);
    });

    test('vehicleDisplay returns correct text', () {
      final unassigned = MachineryApplication.fromJson(baseJson);
      expect(unassigned.vehicleDisplay, '未指派');

      final assigned = MachineryApplication.fromJson({
        ...baseJson,
        'assigned_plate': '京A12345',
        'assigned_vehicle_type': '汽车吊',
        'assigned_vehicle_model': 'QY25K',
      });
      expect(assigned.vehicleDisplay, '京A12345 汽车吊 QY25K');
    });
  });

  group('MachineryCostItem', () {
    test('fromJson basic', () {
      final json = {
        'application_no': 'MC001',
        'applicant_dept': '运输队',
        'scheduled_start': '2026-06-10',
        'scheduled_end': '2026-06-10',
        'working_hours': 8.5,
        'hourly_rate': 200,
        'total_cost': 1700,
        'status': 'completed',
        'application_type': 'short_term',
      };
      final item = MachineryCostItem.fromJson(json);
      expect(item.applicationNo, 'MC001');
      expect(item.applicantDept, '运输队');
      expect(item.workingHours, 8.5);
      expect(item.hourlyRate, 200);
      expect(item.totalCost, 1700);
      expect(item.status, 'completed');
    });
  });
}
