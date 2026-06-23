import 'package:flutter/material.dart';
import '../config/color_constants.dart';

/// 通知消息模型
class NotificationItem {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String content;
  final int? orderId;
  final bool isRead;
  final String? createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    this.orderId,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      type: (json['type'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      orderId: json['order_id'] as int?,
      isRead: (json['is_read'] as int? ?? 0) == 1,
      createdAt: json['created_at'] as String?,
    );
  }

  /// 通知类型对应的图标
  IconData get typeIcon {
    switch (type) {
      // 报修
      case 'new_order':
      case 'new_external_order':
        return Icons.add_alert_rounded;
      case 'order_accepted':
        return Icons.check_circle_outline;
      // 报价
      case 'quote_pending':
        return Icons.request_quote;
      case 'quote_approved':
        return Icons.verified_outlined;
      case 'quote_rejected':
        return Icons.cancel_outlined;
      // 维修进度
      case 'repair_completed':
        return Icons.build_circle_outlined;
      case 'progress_update':
        return Icons.timeline;
      // 加急
      case 'urgent':
      case 'order_urgent':
        return Icons.priority_high;
      // 隐患
      case 'new_hazard':
      case 'hazard_assigned':
        return Icons.warning_amber_rounded;
      case 'hazard_completed':
        return Icons.task_alt;
      case 'hazard_verified':
        return Icons.verified_user;
      case 'hazard_rejected':
        return Icons.gpp_bad_outlined;
      // 工程机械
      case 'new_machinery':
      case 'machinery_dispatch':
      case 'machinery_assigned':
        return Icons.local_shipping;
      case 'machinery_revoked':
        return Icons.undo;
      // 考核
      case 'assessment_issued':
        return Icons.assignment_late;
      default:
        return Icons.email_outlined;
    }
  }

  /// 通知类型对应的颜色
  Color get typeColor {
    switch (type) {
      case 'new_order':
      case 'new_external_order':
        return AppColors.gold;
      case 'order_accepted':
      case 'quote_approved':
      case 'hazard_verified':
        return AppColors.success;
      case 'quote_rejected':
      case 'hazard_rejected':
        return AppColors.danger;
      case 'quote_pending':
        return AppColors.warning;
      case 'urgent':
      case 'order_urgent':
        return AppColors.danger;
      case 'repair_completed':
      case 'progress_update':
        return const Color(0xFF5b9bd5);
      case 'new_hazard':
      case 'hazard_assigned':
      case 'hazard_completed':
        return AppColors.warning;
      case 'new_machinery':
      case 'machinery_dispatch':
      case 'machinery_assigned':
      case 'machinery_revoked':
        return const Color(0xFF7b68ee);
      default:
        return AppColors.text2;
    }
  }

  /// 相对时间（数据库存UTC时间，需先转local再比较）
  String get relativeTime {
    if (createdAt == null) return '';
    try {
      // better-sqlite3 的 CURRENT_TIMESTAMP 返回 UTC 时间，
      // 格式为 "YYYY-MM-DD HH:MM:SS"，Dart 默认当本地时间解析，
      // 在 UTC+8 时区会差 8 小时。显式标记为 UTC 后转本地。
      final raw = createdAt!.trim();
      final isoStr = raw.contains('T')
          ? (raw.endsWith('Z') ? raw : '$raw Z')
          : '${raw.replaceFirst(' ', 'T')}Z';
      final dt = DateTime.parse(isoStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return createdAt!.substring(0, 10);
    } catch (_) {
      return createdAt!.substring(0, 16);
    }
  }
}

/// 通知列表结果
class NotificationListResult {
  final List<NotificationItem> list;
  final int unread;

  NotificationListResult({
    required this.list,
    required this.unread,
  });
}
