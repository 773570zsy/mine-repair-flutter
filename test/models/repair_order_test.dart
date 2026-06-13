import 'package:flutter_test/flutter_test.dart';
import 'package:mine_repair_flutter/models/repair_order.dart';

void main() {
  group('RepairOrder', () {
    final baseJson = {
      'id': 1,
      'driver_id': 10,
      'vehicle_id': 5,
      'repair_shop_id': 2,
      'order_no': 'JL202606099104',
      'fault_description': '发动机异响',
      'status': 'pending_accept',
      'is_urgent': 0,
      'plate_number': '京A12345',
      'vehicle_type': '汽车吊',
      'driver_name': '张三',
      'driver_phone': '13800001111',
      'repair_shop_name': '通达修理厂',
      'dept_name': '运输队',
      'quote_amount': 1500.0,
      'parts_cost': 800.0,
      'labor_cost': 500.0,
      'hours_cost': 200.0,
      'estimated_days': 3,
    };

    test('fromJson parses basic fields', () {
      final order = RepairOrder.fromJson(baseJson);
      expect(order.id, 1);
      expect(order.orderNo, 'JL202606099104');
      expect(order.faultDescription, '发动机异响');
      expect(order.status, 'pending_accept');
      expect(order.isUrgent, isFalse);
      expect(order.plateNumber, '京A12345');
      expect(order.driverName, '张三');
      expect(order.quoteAmount, 1500.0);
      expect(order.estimatedDays, 3);
    });

    test('fromJson default values for missing fields', () {
      final order = RepairOrder.fromJson({'id': 1, 'driver_id': 2, 'order_no': 'T1', 'fault_description': 'test', 'status': 'pending_accept'});
      expect(order.isUrgent, isFalse);
      expect(order.faultImages, isEmpty);
    });

    test('isUrgent parsed from int flag', () {
      final urgent = RepairOrder.fromJson({...baseJson, 'is_urgent': 1});
      expect(urgent.isUrgent, isTrue);
    });

    test('fault_images parsed from JSON string', () {
      final json = {...baseJson, 'fault_images': '["a.jpg","b.jpg"]'};
      final order = RepairOrder.fromJson(json);
      expect(order.faultImages, ['a.jpg', 'b.jpg']);
    });

    test('fault_images parsed from List', () {
      final json = {...baseJson, 'fault_images': ['x.jpg', 'y.jpg']};
      final order = RepairOrder.fromJson(json);
      expect(order.faultImages, ['x.jpg', 'y.jpg']);
    });

    test('fault_images handles empty/null', () {
      final a = RepairOrder.fromJson({...baseJson, 'fault_images': null});
      final b = RepairOrder.fromJson({...baseJson, 'fault_images': ''});
      expect(a.faultImages, isEmpty);
      expect(b.faultImages, isEmpty);
    });

    // Status helpers
    test('status boolean getters', () {
      final tests = {
        'pending_accept': ['isPendingAccept'],
        'pending_quote': ['isPendingQuote'],
        'pending_approval': ['isPendingApproval'],
        'approved': ['isApproved'],
        'rejected': ['isRejected'],
        'repairing': ['isRepairing'],
        'completed': ['isCompleted'],
        'accepted': ['isAccepted'],
        'cancelled': ['isCancelled'],
      };
      for (final e in tests.entries) {
        final o = RepairOrder.fromJson({...baseJson, 'status': e.key});
        for (final getter in e.value) {
          expect(_getBool(o, getter), isTrue, reason: '$e.key => $getter');
        }
      }
    });

    test('action permission getters', () {
      final pendingAccept = RepairOrder.fromJson({...baseJson, 'status': 'pending_accept'});
      expect(pendingAccept.canAccept, isTrue);
      expect(pendingAccept.canQuote, isFalse);
      expect(pendingAccept.canApprove, isFalse);

      final pendingApproval = RepairOrder.fromJson({...baseJson, 'status': 'pending_approval'});
      expect(pendingApproval.canApprove, isTrue);
      expect(pendingApproval.canAccept, isFalse);

      final completed = RepairOrder.fromJson({...baseJson, 'status': 'completed'});
      expect(completed.canVerify, isTrue);
      expect(completed.canComplete, isFalse);

      final approved = RepairOrder.fromJson({...baseJson, 'status': 'approved'});
      expect(approved.canUpdateProgress, isTrue);
      expect(approved.canComplete, isTrue);
    });
  });

  group('RepairProgress', () {
    test('fromJson basic', () {
      final json = {
        'id': 1,
        'order_id': 10,
        'user_id': 5,
        'action': 'accepted_order',
        'content': '已接单，开始维修',
        'created_at': '2026-06-09',
        'user_name': '李四',
        'user_role': 'repair_shop',
      };
      final progress = RepairProgress.fromJson(json);
      expect(progress.id, 1);
      expect(progress.orderId, 10);
      expect(progress.action, 'accepted_order');
      expect(progress.images, isEmpty);
    });

    test('fromJson images from List', () {
      final json = {
        'id': 1, 'order_id': 1, 'user_id': 1, 'action': 'progress_update',
        'content': 'test', 'images': ['p1.jpg'],
      };
      expect(RepairProgress.fromJson(json).images, ['p1.jpg']);
    });

    test('fromJson images from JSON string', () {
      final json = {
        'id': 1, 'order_id': 1, 'user_id': 1, 'action': 'progress_update',
        'content': 'test', 'images': '["p1.jpg","p2.jpg"]',
      };
      expect(RepairProgress.fromJson(json).images, ['p1.jpg', 'p2.jpg']);
    });
  });
}

bool _getBool(dynamic obj, String name) {
  switch (name) {
    case 'isPendingAccept': return (obj as RepairOrder).isPendingAccept;
    case 'isPendingQuote': return obj.isPendingQuote;
    case 'isPendingApproval': return obj.isPendingApproval;
    case 'isApproved': return obj.isApproved;
    case 'isRejected': return obj.isRejected;
    case 'isRepairing': return obj.isRepairing;
    case 'isCompleted': return obj.isCompleted;
    case 'isAccepted': return obj.isAccepted;
    case 'isCancelled': return obj.isCancelled;
    default: throw ArgumentError('Unknown getter: $name');
  }
}
