import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../config/constants.dart';
import '../../models/repair_order.dart';
import '../../config/api_config.dart';
import '../../widgets/photo_viewer.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'pending_accept':
    case 'pending_quote':
    case 'pending_approval':
      return AppColors.warning;
    case 'approved':
    case 'repairing':
      return AppColors.info;
    case 'completed':
    case 'accepted':
      return AppColors.success;
    case 'rejected':
    case 'cancelled':
      return AppColors.danger;
    default:
      return AppColors.text2;
  }
}

// ==================== 表格式工单列表 ====================

class OrderTable extends StatelessWidget {
  final List<RepairOrder> orders;
  final String role;

  const OrderTable({super.key, required this.orders, this.role = 'driver'});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('暂无工单', style: TextStyle(color: AppColors.text2, fontSize: 13))),
      );
    }

    final showRepairShop = role == 'driver' || role == 'leader' || role == 'admin';
    final showDriver = role == 'repair_shop' || role == 'leader' || role == 'admin';

    return Column(children: [
      _TableHeader(columns: _buildColumns(showRepairShop: showRepairShop, showDriver: showDriver)),
      ...orders.map((o) => _OrderRow(order: o, showRepairShop: showRepairShop, showDriver: showDriver, role: role)),
    ]);
  }

  List<String> _buildColumns({required bool showRepairShop, required bool showDriver}) {
    if (role == 'admin' || role == 'leader') {
      return ['工单号', '车辆', '驾驶员', '修理厂', '报价', '状态', '时间', '操作'];
    }
    final cols = <String>['工单号', '车辆', '故障描述', '状态'];
    if (showDriver) cols.insert(2, '报修人');
    if (showRepairShop) cols.add('修理厂');
    cols.add('操作');
    return cols;
  }
}

class _TableHeader extends StatelessWidget {
  final List<String> columns;
  const _TableHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: columns.map((c) {
          int flex = 1;
          if (c == '工单号') flex = 2;
          if (c == '故障描述') flex = 2;
          if (c == '修理厂') flex = 1;
          return Expanded(
            flex: flex,
            child: Text(c, style: const TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600)),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final RepairOrder order;
  final bool showRepairShop, showDriver;
  final String role;

  const _OrderRow({required this.order, required this.showRepairShop, required this.showDriver, required this.role});

  @override
  Widget build(BuildContext context) {
    final statusLabel = statusMap[order.status] ?? order.status;
    final color = _statusColor(order.status);
    final isAdmin = role == 'admin' || role == 'leader';

    return InkWell(
      onTap: () => context.push('/repair/detail/${order.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: isAdmin ? _buildAdminRow(context, statusLabel, color) : _buildDefaultRow(context, statusLabel, color),
      ),
    );
  }

  Widget _buildAdminRow(BuildContext context, String statusLabel, Color color) {
    return Row(children: [
      Expanded(flex: 2, child: _orderNoCell()),
      Expanded(flex: 1, child: Text(order.plateNumber ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text))),
      Expanded(flex: 1, child: Text(order.driverName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
      Expanded(flex: 1, child: Text(order.repairShopName ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
      Expanded(flex: 1, child: Text(order.quoteAmount != null ? '¥${order.quoteAmount!.toStringAsFixed(0)}' : '-', style: TextStyle(fontSize: 11, color: order.quoteAmount != null ? AppColors.danger : AppColors.text2))),
      Expanded(flex: 1, child: _statusBadge(statusLabel, color)),
      Expanded(flex: 1, child: Text(order.createdAt != null ? order.createdAt!.substring(0, 16) : '', style: const TextStyle(fontSize: 10, color: AppColors.text2))),
      Expanded(flex: 1, child: _actionBtn(context)),
    ]);
  }

  Widget _buildDefaultRow(BuildContext context, String statusLabel, Color color) {
    return Row(children: [
      Expanded(flex: 2, child: _orderNoCell()),
      Expanded(flex: 1, child: Text(order.plateNumber ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text))),
      if (showDriver) Expanded(flex: 1, child: Text(order.driverName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
      Expanded(flex: 2, child: Text(order.faultDescription, style: const TextStyle(fontSize: 11, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
      Expanded(flex: 1, child: _statusBadge(statusLabel, color)),
      if (showRepairShop) Expanded(flex: 1, child: Text(order.repairShopName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
      Expanded(flex: 1, child: _actionBtn(context)),
    ]);
  }

  Widget _orderNoCell() {
    return Row(children: [
      Flexible(child: Text(order.orderNo, style: const TextStyle(fontSize: 11, color: AppColors.text, fontWeight: FontWeight.w500))),
      if (order.isUrgent)
        Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3)),
          child: const Text('急', style: TextStyle(fontSize: 9, color: Colors.white)),
        ),
    ]);
  }

  static Widget _statusBadge(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _actionBtn(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/repair/detail/${order.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFb87333)]),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('详情', style: TextStyle(fontSize: 11, color: AppColors.bg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ==================== 紧凑卡片 ====================

class CompactOrderCard extends StatelessWidget {
  final RepairOrder order;
  final Widget? trailing;

  const CompactOrderCard({super.key, required this.order, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/repair/detail/${order.id}'),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(order.plateNumber ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(width: 8),
                Text(order.orderNo, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                if (order.isUrgent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3)),
                    child: const Text('急', style: TextStyle(fontSize: 9, color: Colors.white)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(order.faultDescription, style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                if (order.driverName != null) Text(order.driverName!, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                if (order.repairShopName != null) ...[
                  const Text(' · ', style: TextStyle(fontSize: 11, color: AppColors.text2)),
                  Text(order.repairShopName!, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                ],
                const Spacer(),
                if (order.quoteAmount != null)
                  Text('¥${order.quoteAmount!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gold)),
              ]),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

// ==================== 照片缩略图 ====================

/// 照片缩略图 — 点击打开全屏多图轮播查看器
///
/// [allPaths]: 同组所有照片URL（不传则只显示当前这张）
/// [index]: 当前照片在 allPaths 中的位置
class PhotoThumbnail extends StatelessWidget {
  final String path;
  final double size;
  final List<String>? allPaths;
  final int? index;

  const PhotoThumbnail({
    super.key,
    required this.path,
    this.size = 60,
    this.allPaths,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.fileUrl(path);
    return GestureDetector(
      onTap: () {
        final images = (allPaths != null && allPaths!.isNotEmpty)
            ? allPaths!.map((p) => ApiConfig.fileUrl(p)).toList()
            : [url];
        final startIdx = (index != null && allPaths != null)
            ? index!.clamp(0, allPaths!.length - 1)
            : 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewer(images: images, initialIndex: startIdx),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size, height: size, color: AppColors.surface2,
            child: const Icon(Icons.broken_image, color: AppColors.text2, size: 20),
          ),
        ),
      ),
    );
  }
}
