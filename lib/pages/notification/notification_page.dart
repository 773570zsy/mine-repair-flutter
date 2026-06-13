import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_item.dart';

class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('消息通知'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          listAsync.whenOrNull(data: (result) {
                if (result.list.isEmpty) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () async {
                    await ref.read(notificationActionsProvider.notifier).markAllRead();
                    ref.invalidate(notificationListProvider);
                    ref.read(unreadCountProvider.notifier).clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('全部已读'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('全部已读', style: TextStyle(color: AppColors.gold, fontSize: 13)),
                );
              }) ??
              const SizedBox.shrink(),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.text2),
            const SizedBox(height: 12),
            Text('$e', style: const TextStyle(color: AppColors.text2, fontSize: 13)),
          ]),
        ),
        data: (result) {
          if (result.list.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.email_outlined, size: 64, color: AppColors.text2),
                SizedBox(height: 16),
                Text('暂无通知', style: TextStyle(fontSize: 16, color: AppColors.text2)),
                SizedBox(height: 4),
                Text('新的报修、审批、进度消息将显示在这里', style: TextStyle(fontSize: 13, color: AppColors.text2)),
              ]),
            );
          }

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async {
              ref.invalidate(notificationListProvider);
              ref.read(unreadCountProvider.notifier).refresh();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: result.list.length,
              separatorBuilder: (_, i) => const Divider(color: AppColors.border, height: 1, indent: 60),
              itemBuilder: (context, index) {
                final item = result.list[index];
                return _NotificationTile(
                  item: item,
                  onTap: () => _handleTap(context, ref, item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, NotificationItem item) async {
    if (!item.isRead) {
      await ref.read(notificationActionsProvider.notifier).markRead(item.id);
      ref.invalidate(notificationListProvider);
      ref.read(unreadCountProvider.notifier).decrement();
    }
    if (!context.mounted) return;

    // 根据通知类型导航到对应页面
    if (item.orderId != null) {
      final t = item.type;
      if (t == 'new_order' || t == 'order_accepted' || t == 'repair_completed') {
        context.push('/repair/detail/${item.orderId}');
      } else if (t == 'new_external_order' || t == 'quote_pending' || t == 'quote_approved' || t == 'quote_rejected') {
        context.push('/external-repair/detail/${item.orderId}');
      } else if (t == 'machinery_dispatch' || t == 'machinery_assigned' || t == 'new_machinery') {
        context.push('/machinery/detail/${item.orderId}');
      }
    }
    // hazard 类通知暂不跳转（隐患模块没有独立详情路由）
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.typeColor;
    return Material(
      color: item.isRead ? AppColors.bg : AppColors.surface.withAlpha(150),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 类型图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.isRead ? AppColors.surface2 : color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.typeIcon, size: 20, color: item.isRead ? AppColors.text2 : color),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead ? FontWeight.normal : FontWeight.w600,
                              color: item.isRead ? AppColors.text2 : AppColors.text,
                            ),
                          ),
                        ),
                        Text(item.relativeTime, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.content,
                      style: const TextStyle(fontSize: 12, color: AppColors.text2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 未读圆点
              if (!item.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
