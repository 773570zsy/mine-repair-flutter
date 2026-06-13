import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../config/api_config.dart';
import '../../models/external_repair_order.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/external_repair_provider.dart';
import '../../widgets/photo_viewer.dart';

class ExternalOrderDetailPage extends ConsumerStatefulWidget {
  final int orderId;
  const ExternalOrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<ExternalOrderDetailPage> createState() => _State();
}

class _State extends ConsumerState<ExternalOrderDetailPage> {
  int get _id => widget.orderId;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(externalOrderDetailProvider(_id));
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('外修详情'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (detail) {
          final o = detail.order;
          final progress = detail.progress;
          return Column(children: [
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _infoCard(o),
                const SizedBox(height: 10),
                _faultCard(o),
                if (o.quoteAmount != null && o.quoteAmount! > 0) ...[
                  const SizedBox(height: 10),
                  _quoteCard(o),
                ],
                const SizedBox(height: 10),
                _progressTimeline(progress),
              ]),
            )),
            if (user != null) _actionBar(o, user),
          ]);
        },
      ),
    );
  }

  Widget _infoCard(ExternalRepairOrder o) {
    final stLabel = externalStatusMap[o.status] ?? o.status;
    final stColor = _statusColor(o.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('单号：${o.orderNo}', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          const Spacer(),
          if (o.isUrgent) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: const Text('加急维修', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        _row(Icons.directions_car, '车辆', o.vehicleName),
        const SizedBox(height: 6),
        _row(Icons.business, '部门', o.deptName ?? ''),
        const SizedBox(height: 6),
        _row(Icons.person, '报修人', o.userName ?? ''),
        if (o.repairShopName != null) ...[const SizedBox(height: 6), _row(Icons.build, '修理厂', o.repairShopName!)],
        const SizedBox(height: 6),
        _row(Icons.access_time, '报修时间', (o.createdAt ?? '').replaceAll('T', ' ').substring(0, 16)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: stColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3), border: Border.all(color: stColor.withValues(alpha: 0.3))), child: Text(stLabel, style: TextStyle(fontSize: 12, color: stColor, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _faultCard(ExternalRepairOrder o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('故障描述', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        Text(o.faultDescription, style: const TextStyle(fontSize: 14, color: AppColors.text)),
        if (o.faultImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: o.faultImages.asMap().entries.map((e) {
            final url = ApiConfig.fileUrl(e.value);
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewer(images: o.faultImages.map((p) => ApiConfig.fileUrl(p)).toList(), initialIndex: e.key))),
              child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppColors.surface2, child: const Icon(Icons.broken_image, color: AppColors.text2)))),
            );
          }).toList()),
        ],
      ]),
    );
  }

  Widget _quoteCard(ExternalRepairOrder o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('报价信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        Row(children: [const Text('报价金额：', style: TextStyle(fontSize: 14, color: AppColors.text2)), Text('¥${(o.quoteAmount ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold))]),
        if ((o.partsCost ?? 0) > 0) ...[const SizedBox(height: 4), Text('配件费用：¥${o.partsCost!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: AppColors.text2))],
        if ((o.laborCost ?? 0) > 0) ...[const SizedBox(height: 4), Text('工时费用：¥${o.laborCost!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: AppColors.text2))],
        if ((o.hoursCost ?? 0) > 0) ...[const SizedBox(height: 4), Text('台班费用：¥${o.hoursCost!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: AppColors.text2))],
        if (o.estimatedDays != null) ...[const SizedBox(height: 4), Text('预估天数：${o.estimatedDays} 天', style: const TextStyle(fontSize: 13, color: AppColors.text2))],
        if (o.quoteDetail != null && o.quoteDetail!.isNotEmpty) ...[const SizedBox(height: 6), Text('说明：${o.quoteDetail}', style: const TextStyle(fontSize: 13, color: AppColors.text2))],
        if (o.rejectReason != null && o.rejectReason!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Row(children: [const Icon(Icons.error_outline, color: AppColors.danger, size: 18), const SizedBox(width: 8), Expanded(child: Text('驳回原因：${o.rejectReason}', style: const TextStyle(color: AppColors.danger, fontSize: 13)))])),
        ],
      ]),
    );
  }

  Widget _progressTimeline(List<ExternalRepairProgress> list) {
    if (list.isEmpty) return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Center(child: Text('暂无进度记录', style: TextStyle(color: AppColors.text2))));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('维修进度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        ...list.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final label = externalActionNameMap[p.action] ?? p.action;
          final time = (p.createdAt ?? '').replaceAll('T', ' ').substring(0, 16);
          return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: i == 0 ? AppColors.gold : AppColors.text2, shape: BoxShape.circle)),
              if (i < list.length - 1) Expanded(child: Container(width: 2, color: AppColors.border)),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: EdgeInsets.only(bottom: i < list.length - 1 ? 16 : 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(children: [TextSpan(text: label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)), TextSpan(text: '  $time', style: const TextStyle(fontSize: 11, color: AppColors.text2))])),
              if (p.content != null && p.content!.isNotEmpty) ...[const SizedBox(height: 4), Text(p.content!, style: const TextStyle(fontSize: 13, color: AppColors.text2))],
              if (p.userName != null) Text('— ${p.userName}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]))),
          ]));
        }),
      ]),
    );
  }

  Widget _actionBar(ExternalRepairOrder o, User user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, border: const Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(child: Row(children: [
        // 报修人：验收
        if (user.id == o.userId && o.canVerify)
          Expanded(child: ElevatedButton.icon(onPressed: () => _do(() => ref.read(externalRepairActionsProvider.notifier).acceptCompletion(_id), '已验收'), icon: const Icon(Icons.check_circle), label: const Text('确认验收'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
        // 报修人：审批报价
        if (user.id == o.userId && o.canApprove) ...[
          Expanded(child: ElevatedButton.icon(onPressed: () => _do(() => ref.read(externalRepairActionsProvider.notifier).approveQuote(orderId: _id, approved: true), '审批通过'), icon: const Icon(Icons.check), label: const Text('通过报价'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(width: 8),
          Expanded(child: _rejectBtn()),
        ],
        // 修理厂：接单+报价
        if (user.isRepairShop && o.canAccept)
          Expanded(child: ElevatedButton.icon(onPressed: _showAcceptDialog, icon: const Icon(Icons.assignment_turned_in), label: const Text('接单并报价'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 12)))),
        // 修理厂：更新进度+完工
        if (user.isRepairShop && o.canUpdateProgress) ...[
          Expanded(child: ElevatedButton.icon(onPressed: _showProgressDialog, icon: const Icon(Icons.edit_note), label: const Text('更新进度'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(onPressed: () => _do(() => ref.read(externalRepairActionsProvider.notifier).completeOrder(_id), '已完工'), icon: const Icon(Icons.check), label: const Text('完工'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
        ],
        // 领导/管理员：审批（也能替报修人审批）
        if ((user.isLeader || user.isAdmin) && o.canApprove) ...[
          Expanded(child: ElevatedButton.icon(onPressed: () => _do(() => ref.read(externalRepairActionsProvider.notifier).approveQuote(orderId: _id, approved: true), '审批通过'), icon: const Icon(Icons.check), label: const Text('通过'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(width: 8),
          Expanded(child: _rejectBtn()),
        ],
        // 领导/管理员：加急
        if ((user.isLeader || user.isAdmin) && !o.isUrgent && o.status != 'accepted' && o.status != 'cancelled') ...[
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => _do(() => ref.read(externalRepairActionsProvider.notifier).markUrgent(_id), '已标记加急'), icon: const Icon(Icons.priority_high, color: AppColors.danger), label: const Text('标记加急', style: TextStyle(color: AppColors.danger)), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger), padding: const EdgeInsets.symmetric(vertical: 12)))),
        ],
      ])),
    );
  }

  Widget _rejectBtn() {
    return ElevatedButton.icon(
      onPressed: () {
        final ctrl = TextEditingController();
        showDialog(context: context, builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface, title: const Text('驳回原因', style: TextStyle(color: AppColors.text)),
          content: TextField(controller: ctrl, maxLines: 3, autofocus: true, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: '请填写驳回原因...', border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(onPressed: () { final r = ctrl.text.trim(); if (r.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写驳回原因'))); return; } Navigator.pop(ctx); _do(() => ref.read(externalRepairActionsProvider.notifier).approveQuote(orderId: _id, approved: false, rejectReason: r), '已驳回'); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white), child: const Text('确认驳回')),
          ],
        ));
      },
      icon: const Icon(Icons.close), label: const Text('驳回'),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
    );
  }

  void _showAcceptDialog() {
    final amountCtrl = TextEditingController(); final partsCtrl = TextEditingController(); final laborCtrl = TextEditingController(); final hoursCtrl = TextEditingController(); final daysCtrl = TextEditingController(); final detailCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface, title: const Text('接单并填写报价', style: TextStyle(color: AppColors.text, fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _df(ctx, '报价金额 (¥)', amountCtrl, keyboardType: TextInputType.number), const SizedBox(height: 8),
        _df(ctx, '配件费用 (¥)', partsCtrl, keyboardType: TextInputType.number), const SizedBox(height: 8),
        _df(ctx, '工时费用 (¥)', laborCtrl, keyboardType: TextInputType.number), const SizedBox(height: 8),
        _df(ctx, '台班费用 (¥)', hoursCtrl, keyboardType: TextInputType.number), const SizedBox(height: 8),
        _df(ctx, '预估天数', daysCtrl, keyboardType: TextInputType.number), const SizedBox(height: 8),
        TextField(controller: detailCtrl, maxLines: 2, style: const TextStyle(color: AppColors.text, fontSize: 13), decoration: const InputDecoration(labelText: '报价说明', labelStyle: TextStyle(color: AppColors.text2, fontSize: 12), filled: true, fillColor: AppColors.bg, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
        ElevatedButton(onPressed: () async {
          final amount = double.tryParse(amountCtrl.text) ?? 0;
          if (amount <= 0) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写报价金额'))); return; }
          Navigator.pop(ctx);
          try {
            await ref.read(externalRepairActionsProvider.notifier).acceptAndQuote(orderId: _id, quoteAmount: amount, partsCost: double.tryParse(partsCtrl.text) ?? 0, laborCost: double.tryParse(laborCtrl.text) ?? 0, hoursCost: double.tryParse(hoursCtrl.text) ?? 0, quoteDetail: detailCtrl.text, estimatedDays: int.tryParse(daysCtrl.text));
            if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('接单成功'))); ref.invalidate(externalOrderDetailProvider(_id)); }
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg), child: const Text('确认接单')),
      ],
    ));
  }

  void _showProgressDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface, title: const Text('更新维修进度', style: TextStyle(color: AppColors.text)),
      content: TextField(controller: ctrl, maxLines: 4, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: '请描述当前维修进度...', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
        ElevatedButton(onPressed: () async {
          final content = ctrl.text.trim();
          if (content.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写进度描述'))); return; }
          Navigator.pop(ctx);
          try { await ref.read(externalRepairActionsProvider.notifier).updateProgress(orderId: _id, content: content); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('进度已更新'))); ref.invalidate(externalOrderDetailProvider(_id)); } }
          catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg), child: const Text('提交')),
      ],
    ));
  }

  Widget _df(BuildContext ctx, String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return TextField(controller: ctrl, keyboardType: keyboardType, style: const TextStyle(color: AppColors.text, fontSize: 13), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppColors.text2, fontSize: 12), filled: true, fillColor: AppColors.bg, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border))));
  }

  Future<void> _do(Future<void> Function() action, String msg) async {
    try {
      await action();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); ref.invalidate(externalOrderDetailProvider(_id)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending_accept': case 'pending_approval': case 'completed': return AppColors.warning;
      case 'approved': case 'repairing': return AppColors.info;
      case 'accepted': return AppColors.success;
      case 'rejected': case 'cancelled': return AppColors.danger;
      default: return AppColors.text2;
    }
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.gold), const SizedBox(width: 8),
      Text('$label：', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w500))),
    ]);
  }
}
