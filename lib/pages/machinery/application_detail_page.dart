import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/machinery.dart';
import '../../services/machinery_service.dart';
import '../../providers/machinery_provider.dart';
import '../../providers/auth_provider.dart';

import '../../config/color_constants.dart';

class ApplicationDetailPage extends ConsumerStatefulWidget {
  final int appId;
  const ApplicationDetailPage({super.key, required this.appId});

  @override
  ConsumerState<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends ConsumerState<ApplicationDetailPage> {
  late Future<MachineryApplication> _future;

  @override
  void initState() {
    super.initState();
    _future = MachineryService().getDetail(widget.appId);
  }

  bool _canDispatch() {
    final role = ref.watch(authProvider).user?.role ?? '';
    return role == 'admin' || role == 'dispatcher';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return AppColors.warning;
      case 'assigned':
      case 'in_progress': return const Color(0xFF2980b9);
      case 'completed':
      case 'early_completed': return AppColors.success;
      case 'cancelled': return AppColors.text2;
      default: return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('申请详情'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: FutureBuilder<MachineryApplication>(
        future: _future,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}', style: const TextStyle(color: AppColors.danger)));
          }
          final app = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 头部
              _headerCard(app),
              const SizedBox(height: 12),
              // 申请信息
              _section('申请信息', [
                _row('申请编号', '订单号：${app.applicationNo}'),
                _row('申请部门', app.applicantDept),
                _row('费供', app.feeProviderLabel),
                _row('申请人', app.applicantName),
                _row('联系电话', app.applicantPhone),
                _row('申请类型', app.typeLabel),
                _row('紧急程度', app.urgencyLabel),
                _row('状态', app.statusLabel, valueColor: _statusColor(app.status)),
              ]),
              const SizedBox(height: 12),
              // 用车需求
              _section('用车需求', [
                _row('车辆类型', app.vehicleType),
                _row('预用车时间', '${app.scheduledStart} ~ ${app.scheduledEnd}'),
                _row('作业地点', app.workLocation),
                _row('作业海拔', app.workAltitude ?? '-'),
                _row('作业用途', app.workPurpose),
                _row('危险作业', app.isHazardous ? '是 ⚠️' : '否'),
              ]),
              const SizedBox(height: 12),
              // 派车信息（如果已指派）
              if (app.assignedVehicleId != null) ...[
                _section('派车信息', [
                  _row('指派车辆', app.vehicleDisplay),
                  _row('指派驾驶员', app.driverName ?? '-', valueColor: AppColors.gold),
                  _row('驾驶员电话', app.driverPhone ?? '-'),
                  _row('调度员', app.dispatcherName ?? '-'),
                  _row('小时单价', '¥${(app.hourlyRate ?? 0).toStringAsFixed(2)}/小时'),
                ]),
                const SizedBox(height: 12),
              ],
              // 结算信息（如果已完成）
              if (app.isCompleted) ...[
                _section('结算信息', [
                  _row('实际结束时间', app.actualEndTime ?? '-'),
                  _row('结算结束时间', app.settlementEndTime ?? '-'),
                  _row('工作工时', '${(app.workingHours ?? 0).toStringAsFixed(2)} h'),
                  _row('总费用', '¥${(app.totalCost ?? 0).toStringAsFixed(2)}', valueColor: AppColors.danger),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }

  Future<void> _revokeAssign(MachineryApplication app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认撤销指派', style: TextStyle(color: AppColors.text)),
        content: Text('确认撤销 "${app.applicationNo}" 的指派吗？\n订单将回到待指派列表。', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            child: const Text('确认撤销'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(machineryActionsProvider).revokeAssign(app.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('指派已撤销')));
        setState(() { _future = MachineryService().getDetail(widget.appId); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _earlyEnd(MachineryApplication app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认提前结束', style: TextStyle(color: AppColors.text)),
        content: Text('确认结束用车 "${app.applicationNo}" 吗？', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MachineryService().earlyEnd(app.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用车已结束')));
        setState(() { _future = MachineryService().getDetail(widget.appId); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _headerCard(MachineryApplication app) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _statusColor(app.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _statusColor(app.status).withValues(alpha: 0.3))),
          child: Text(app.statusLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _statusColor(app.status))),
        ),
        const SizedBox(height: 8),
        Text('订单号：${app.applicationNo}', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
        if (app.isActive) ...[
          const SizedBox(height: 10),
          // 撤销指派 — 仅assigned状态且调度员/管理员
          if (app.status == 'assigned' && _canDispatch())
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton.icon(
                  onPressed: () => _revokeAssign(app),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('撤销指派', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _earlyEnd(app),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('提前结束', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? AppColors.text))),
      ]),
    );
  }
}
