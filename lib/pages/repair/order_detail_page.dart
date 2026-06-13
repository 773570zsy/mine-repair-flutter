import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/repair_order.dart';
import '../../models/user.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repair_provider.dart';
import 'order_list_common.dart';

// 暗色主题色（与全部工单页面一致）
import '../../config/color_constants.dart';
// using AppColors






class OrderDetailPage extends ConsumerWidget {
  final int orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(orderDetailProvider(orderId));
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('工单详情'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('加载失败: $e', style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
                child: const Text('重试', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
        data: (detail) {
          final order = detail.order;
          final progressList = detail.progress;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(order),
                      const SizedBox(height: 12),
                      _buildFaultCard(order),
                      const SizedBox(height: 12),
                      if (order.quoteAmount != null)
                        _buildQuoteCard(order),
                      const SizedBox(height: 12),
                      _buildProgressTimeline(progressList),
                    ],
                  ),
                ),
              ),
              if (user != null) _buildActionBar(context, ref, order, user),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(RepairOrder order) {
    final statusLabel = statusMap[order.status] ?? order.status;
    final colorHex = statusTagColor[order.status] ?? '#999';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工单号 + 加急
          Row(
            children: [
              Text('工单号：${order.orderNo}',
                  style: const TextStyle(fontSize: 12, color: AppColors.text2)),
              const Spacer(),
              if (order.isUrgent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('加急维修',
                      style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.directions_car, '车辆', '${order.plateNumber ?? ""}  ${order.vehicleType ?? ""}'),
          const SizedBox(height: 8),
          _infoRow(Icons.person, '驾驶员', '${order.driverName ?? ""}  ${order.driverPhone ?? ""}'),
          if (order.repairShopName != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.build, '修理厂', order.repairShopName!),
          ],
          if (order.deptName != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.business, '所属部门', order.deptName!),
          ],
          if (order.createdAt != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.access_time, '报修时间', order.createdAt!.replaceAll('T', ' ').substring(0, 16)),
          ],
          const SizedBox(height: 8),
          // 状态
          Row(
            children: [
              const Icon(Icons.flag, size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              const Text('状态：', style: TextStyle(fontSize: 13, color: AppColors.text2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoGrid(List<String> paths) {
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: paths.asMap().entries
          .map((e) => PhotoThumbnail(path: e.value, allPaths: paths, index: e.key))
          .toList(),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Text('$label：', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildFaultCard(RepairOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('故障描述', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          Text(order.faultDescription, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.text)),
          if (order.faultImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: order.faultImages.asMap().entries
                  .map((e) => PhotoThumbnail(path: e.value, allPaths: order.faultImages, index: e.key))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteCard(RepairOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('报价信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('报价金额：', style: TextStyle(fontSize: 14, color: AppColors.text2)),
              Text('¥${(order.quoteAmount ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 8),
          if ((order.partsCost ?? 0) > 0)
            Text('配件费用：¥${order.partsCost!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          if ((order.laborCost ?? 0) > 0)
            Text('工时费用：¥${order.laborCost!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          if (order.estimatedDays != null)
            Text('预估天数：${order.estimatedDays} 天', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          if (order.quoteDetail != null && order.quoteDetail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('说明：${order.quoteDetail}', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          ],
          // 损坏配件照片（报价时上传）
          if (order.damagePhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('损坏配件照片', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text2)),
            const SizedBox(height: 6),
            _photoGrid(order.damagePhotos),
          ],
          // 新配件照片（完工时上传）
          if (order.newPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('新配件照片', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text2)),
            const SizedBox(height: 6),
            _photoGrid(order.newPhotos),
          ],
          if (order.rejectReason != null && order.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('驳回原因：${order.rejectReason}',
                        style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(List<RepairProgress> progressList) {
    if (progressList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: Text('暂无进度记录', style: TextStyle(color: AppColors.text2))),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('维修进度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 10),
          ...progressList.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final actionLabel = actionNameMap[p.action] ?? p.action;
            final timeStr = p.createdAt?.replaceAll('T', ' ').substring(0, 16) ?? '';

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间线节点
                  Column(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: i == 0 ? AppColors.gold : AppColors.text2,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < progressList.length - 1)
                        Expanded(
                          child: Container(width: 2, color: AppColors.border),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 内容
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < progressList.length - 1 ? 16 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 动作名 + 时间 — 时间在左侧紧接动作名
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: actionLabel,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                                TextSpan(text: '  $timeStr',
                                    style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(p.content, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
                          if (p.userName != null)
                            Text('— ${p.userName}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                          if (p.images.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: p.images.asMap().entries
                                  .map((e) => PhotoThumbnail(path: e.value, size: 60, allPaths: p.images, index: e.key))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== 底部操作栏 ====================

  Widget _buildActionBar(
      BuildContext context, WidgetRef ref, RepairOrder order, User user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 驾驶员试车验收
            if (user.isDriver && order.canVerify)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/repair/trial-accept/$orderId'),
                  icon: const Icon(Icons.drive_eta),
                  label: const Text('试车验收'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            // 修理厂接单
            if (user.isRepairShop && order.canAccept)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleAction(
                      context, ref, () => ref.read(repairActionsProvider.notifier).acceptRepairOrder(orderId),
                      '接单成功'),
                  icon: const Icon(Icons.assignment_turned_in),
                  label: const Text('确认接单'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFc8a04a),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            // 修理厂报价/更新/完工
            if (user.isRepairShop) ...[
              if (order.canQuote)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/repair/submit-quote/$orderId'),
                    icon: const Icon(Icons.request_quote),
                    label: const Text('提交报价'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFc8a04a),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (order.canUpdateProgress) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/repair/update-progress/$orderId'),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('更新进度'),
                  ),
                ),
              ],
              if (order.canComplete) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(
                        '/repair/update-progress/$orderId?complete=1'),
                    icon: const Icon(Icons.check),
                    label: const Text('完工'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],

            // 领导审批
            if ((user.isLeader || user.isAdmin) && order.canApprove) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleAction(
                      context, ref,
                      () => ref.read(repairActionsProvider.notifier).approveQuote(
                            orderId: orderId, approved: true),
                      '审批通过'),
                  icon: const Icon(Icons.check),
                  label: const Text('通过'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRejectButton(context, ref),
              ),
            ],

            // 领导加急
            if ((user.isLeader || user.isAdmin) &&
                !order.isUrgent &&
                order.status != 'accepted' &&
                order.status != 'cancelled') ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleAction(
                      context, ref,
                      () => ref.read(repairActionsProvider.notifier).markUrgent(orderId),
                      '已标记加急'),
                  icon: const Icon(Icons.priority_high, color: Colors.red),
                  label: const Text('标记加急', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, Future<void> Function() action, String successMsg) async {
    try {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMsg)));
        ref.invalidate(orderDetailProvider(orderId));
        // 同时刷新相关列表
        ref.invalidate(pendingAcceptProvider);
        ref.invalidate(pendingApprovalProvider);
        ref.invalidate(myOrdersProvider(null));
        ref.invalidate(shopOrdersProvider(null));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Widget _buildRejectButton(BuildContext context, WidgetRef ref) {
    final reasonCtrl = TextEditingController();
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('驳回原因'),
            content: TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '请填写驳回原因...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  final reason = reasonCtrl.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('请填写驳回原因')));
                    return;
                  }
                  Navigator.pop(ctx);
                  await _handleAction(context, ref, () {
                    return ref.read(repairActionsProvider.notifier).approveQuote(
                          orderId: orderId,
                          approved: false,
                          rejectReason: reason,
                        );
                  }, '已驳回');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('确认驳回'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.close),
      label: const Text('驳回'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
