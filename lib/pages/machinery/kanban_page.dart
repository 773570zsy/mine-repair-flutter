import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/machinery.dart';
import '../../providers/machinery_provider.dart';

/// 调度看板 — 今日车辆/人员状态总览
class DispatchKanbanPage extends ConsumerStatefulWidget {
  const DispatchKanbanPage({super.key});

  @override
  ConsumerState<DispatchKanbanPage> createState() => _DispatchKanbanPageState();
}

class _DispatchKanbanPageState extends ConsumerState<DispatchKanbanPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(dispatchKanbanProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dispatchKanbanProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('调度看板', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          async.whenData((d) => Text(d.date, style: const TextStyle(fontSize: 12, color: AppColors.text2))).value ?? const SizedBox.shrink(),
        ]),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold, size: 20),
            onPressed: () => ref.invalidate(dispatchKanbanProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (kanban) => RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async => ref.invalidate(dispatchKanbanProvider),
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              _buildSummaryBar(kanban.summary),
              const SizedBox(height: 10),
              if (kanban.vehicles.where((v) => v.isBusy).isNotEmpty) ...[
                _buildSection('忙碌车辆', kanban.summary.busyVehicles, AppColors.gold,
                  kanban.vehicles.where((v) => v.isBusy).map((v) => _buildBusyVehicleCard(v, context)).toList()),
                const SizedBox(height: 10),
              ],
              if (kanban.vehicles.where((v) => v.isAvailable).isNotEmpty) ...[
                _buildSection('空闲车辆', kanban.summary.availableVehicles, AppColors.success,
                  [_buildIdleVehicleRow(kanban.vehicles.where((v) => v.isAvailable).toList())]),
                const SizedBox(height: 10),
              ],
              if (kanban.vehicles.where((v) => v.isRepairing).isNotEmpty) ...[
                _buildSection('维修车辆', kanban.summary.repairingVehicles, AppColors.warning,
                  [_buildRepairingVehicleList(kanban.vehicles.where((v) => v.isRepairing).toList())]),
                const SizedBox(height: 10),
              ],
              if (kanban.drivers.where((d) => d.isBusy).isNotEmpty) ...[
                _buildSection('忙碌驾驶员', kanban.summary.busyDrivers, AppColors.gold,
                  kanban.drivers.where((d) => d.isBusy).map((d) => _buildBusyDriverCard(d, context)).toList()),
                const SizedBox(height: 10),
              ],
              if (kanban.drivers.where((d) => d.isAvailable).isNotEmpty) ...[
                _buildSection('空闲驾驶员', kanban.summary.availableDrivers, AppColors.success,
                  [_buildIdleDriverRow(kanban.drivers.where((d) => d.isAvailable).toList())]),
                const SizedBox(height: 10),
              ],
              if (kanban.drivers.where((d) => d.isOnLeave).isNotEmpty) ...[
                _buildSection('请假', kanban.summary.onLeaveDrivers, AppColors.text2,
                  [_buildLeaveDriverRow(kanban.drivers.where((d) => d.isOnLeave).toList())]),
                const SizedBox(height: 10),
              ],
              if (kanban.pendingApplications.isNotEmpty) ...[
                _buildSection('待指派申请', kanban.summary.pendingCount, AppColors.warning,
                  kanban.pendingApplications.map((a) => _buildPendingCard(a, context)).toList()),
                const SizedBox(height: 10),
              ],
              if (kanban.pendingApplications.isEmpty && kanban.summary.busyVehicles == 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      const Text('今日暂无调度任务', style: TextStyle(fontSize: 14, color: AppColors.text2)),
                      const SizedBox(height: 4),
                      Text('车辆和驾驶员均处于空闲状态', style: TextStyle(fontSize: 12, color: AppColors.text2.withValues(alpha: 0.7))),
                    ]),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 汇总统计栏 ====================

  Widget _buildSummaryBar(KanbanSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          _summarySeg('空闲车辆', '${s.availableVehicles}/${s.totalVehicles}',
            color: s.availableVehicles > 0 ? AppColors.success : AppColors.text2),
          _summaryDivider(),
          _summarySeg('可用驾驶员', '${s.availableDrivers}/${s.totalDrivers}',
            color: s.availableDrivers > 0 ? AppColors.success : AppColors.text2),
          _summaryDivider(),
          _summarySeg('待指派', '${s.pendingCount}单',
            color: s.pendingCount > 0 ? AppColors.danger : AppColors.text2),
          _summaryDivider(),
          _summarySeg('今日出勤', '${s.activeDrivers}/${s.totalDrivers}',
            color: s.activeDrivers > 0 ? AppColors.gold : AppColors.text2),
        ]),
      ),
    );
  }

  Widget _summarySeg(String label, String value, {Color color = AppColors.text}) {
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
      ]),
    );
  }

  Widget _summaryDivider() {
    return const SizedBox(
      height: 36,
      child: VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
    );
  }

  // ==================== 通用区块 ====================

  Widget _buildSection(String title, int count, Color accentColor, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
          ),
        ]),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          border: Border(left: BorderSide(color: AppColors.border), right: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(children: children),
      ),
    ]);
  }

  // ==================== 忙碌车辆卡片 ====================

  Widget _buildBusyVehicleCard(KanbanVehicle v, BuildContext context) {
    final t = v.currentTask!;
    return GestureDetector(
      onTap: () => context.push('/machinery/detail/${t.applicationId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(v.plateNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(width: 6),
                Text(v.vehicleType, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              ]),
              const SizedBox(height: 4),
              Text('驾驶员 ${t.driverName ?? '—'}  ·  地点 ${t.workLocation}  ·  ${t.workPurpose}',
                style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              const SizedBox(height: 2),
              Text('时间 ${t.timeDisplay}  ·  ${t.applicantDept} ${t.applicantName}',
                style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.text2, size: 18),
        ]),
      ),
    );
  }

  // ==================== 空闲车辆（左到右排列） ====================

  Widget _buildIdleVehicleRow(List<KanbanVehicle> vehicles) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 6, runSpacing: 6,
      children: vehicles.map((v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Text('${v.plateNumber} (${v.vehicleType})',
          style: const TextStyle(fontSize: 11, color: AppColors.success)),
      )).toList(),
    );
  }

  // ==================== 维修车辆列表 ====================

  Widget _buildRepairingVehicleList(List<KanbanVehicle> vehicles) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 8, runSpacing: 4,
      children: vehicles.map((v) => Text('${v.plateNumber} (${v.vehicleType})',
        style: const TextStyle(fontSize: 12, color: AppColors.warning))).toList(),
    );
  }

  // ==================== 忙碌驾驶员卡片 ====================

  Widget _buildBusyDriverCard(KanbanDriver d, BuildContext context) {
    final t = d.currentTask!;
    return GestureDetector(
      onTap: () => context.push('/machinery/detail/${t.applicationId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(width: 6),
                Text(d.phone, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              ]),
              const SizedBox(height: 4),
              Text('车辆 ${t.plateNumber ?? '—'}  ·  地点 ${t.workLocation}  ·  ${t.workPurpose}',
                style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              const SizedBox(height: 2),
              Text('时间 ${t.timeDisplay}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.text2, size: 18),
        ]),
      ),
    );
  }

  // ==================== 空闲驾驶员（左到右排列） ====================

  Widget _buildIdleDriverRow(List<KanbanDriver> drivers) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 6, runSpacing: 6,
      children: drivers.map((d) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Text('${d.name} ${d.phone}',
          style: const TextStyle(fontSize: 11, color: AppColors.success)),
      )).toList(),
    );
  }

  // ==================== 请假驾驶员（左到右排列） ====================

  Widget _buildLeaveDriverRow(List<KanbanDriver> drivers) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 8, runSpacing: 4,
      children: drivers.map((d) => Text('${d.name}（${d.attendanceSymbol ?? d.statusLabel}）',
        style: const TextStyle(fontSize: 11, color: AppColors.text2))).toList(),
    );
  }

  // ==================== 待指派申请卡片 ====================

  Widget _buildPendingCard(MachineryApplication a, BuildContext context) {
    final urgencyColor = a.urgency == 'emergency'
        ? AppColors.danger
        : (a.urgency == 'urgent' ? AppColors.warning : AppColors.text2);

    return GestureDetector(
      onTap: () => context.push('/machinery/assign/${a.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: urgencyColor, width: 3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(a.applicationNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                  child: Text(a.urgencyLabel, style: TextStyle(fontSize: 10, color: urgencyColor, fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('${a.vehicleType}  ·  ${a.applicantName}  ·  ${a.applicantDept}',
                style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              const SizedBox(height: 2),
              Text('地点 ${a.workLocation}  ·  时间 ${a.workTimeDisplay}',
                style: const TextStyle(fontSize: 11, color: AppColors.text2)),
            ]),
          ),
          ElevatedButton(
            onPressed: () => context.push('/machinery/assign/${a.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('指派'),
          ),
        ]),
      ),
    );
  }
}
