import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/vehicle.dart';
import '../../models/machinery.dart';
import '../../services/machinery_service.dart';
import '../../providers/machinery_provider.dart';

import '../../config/color_constants.dart';

class AssignPage extends ConsumerStatefulWidget {
  final int appId;
  const AssignPage({super.key, required this.appId});

  @override
  ConsumerState<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends ConsumerState<AssignPage> {
  late Future<MachineryApplication> _appFuture;
  late Future<List<Vehicle>> _vehiclesFuture;
  late Future<List<Map<String, dynamic>>> _driversFuture;
  late Future<Map<String, dynamic>> _busyFuture;

  int? _selectedVehicleId;
  int? _selectedDriverId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final service = MachineryService();
    _appFuture = service.getDetail(widget.appId);
    _vehiclesFuture = service.getAvailableVehicles();
    _driversFuture = service.getDriverList();
    _busyFuture = service.getBusyResources();
  }

  Future<void> _submit() async {
    if (_selectedVehicleId == null) { _snack('请选择车辆'); return; }
    if (_selectedDriverId == null) { _snack('请选择驾驶员'); return; }

    setState(() => _submitting = true);
    try {
      final msg = await ref.read(machineryActionsProvider).assign(
        id: widget.appId,
        assignedVehicleId: _selectedVehicleId!,
        assignedDriverId: _selectedDriverId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('指派车辆和驾驶员'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: FutureBuilder(
        future: Future.wait([_appFuture, _vehiclesFuture, _driversFuture, _busyFuture]),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}', style: const TextStyle(color: AppColors.danger)));
          }
          final results = snapshot.data!;
          final app = results[0] as MachineryApplication;
          final allVehicles = results[1] as List<Vehicle>;
          final drivers = results[2] as List<Map<String, dynamic>>;
          final busy = results[3] as Map<String, dynamic>;

          // 解析繁忙资源
          final busyVehicles = (busy['busyVehicles'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final busyDrivers = (busy['busyDrivers'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

          final busyVehicleIds = busyVehicles.map((b) => b['vehicle_id'] as int).toSet();
          final busyDriverIds = busyDrivers.map((b) => b['driver_id'] as int).toSet();

          // 按申请人车辆类型匹配排序
          final matchType = app.vehicleType;
          final matched = allVehicles.where((v) => v.vehicleType == matchType).toList();
          final others = allVehicles.where((v) => v.vehicleType != matchType).toList();
          final vehicles = [...matched, ...others];

          // 自动推荐：选第一个可用匹配车型
          if (_selectedVehicleId == null && matched.isNotEmpty) {
            final firstFree = matched.where((v) => !busyVehicleIds.contains(v.id)).toList();
            if (firstFree.isNotEmpty) {
              _selectedVehicleId = firstFree.first.id;
            }
          }

          // 如果已选的是busy的，清除选择
          if (_selectedVehicleId != null && busyVehicleIds.contains(_selectedVehicleId)) {
            _selectedVehicleId = null;
          }
          if (_selectedDriverId != null && busyDriverIds.contains(_selectedDriverId)) {
            _selectedDriverId = null;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildAppDetail(app),

              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.directions_car, size: 18, color: AppColors.gold),
                const SizedBox(width: 6),
                const Text('选择车辆', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
                if (matched.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                    child: Text('已推荐 ${matched.length} 辆匹配车型', style: const TextStyle(fontSize: 11, color: AppColors.success)),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              ...vehicles.map((v) {
                final busyInfo = busyVehicles.where((b) => b['vehicle_id'] == v.id).firstOrNull;
                return _vehicleTile(v, isRecommended: v.vehicleType == matchType, busyInfo: busyInfo);
              }),
              if (vehicles.isEmpty) const Text('暂无可用车辆', style: TextStyle(color: AppColors.text2)),

              const SizedBox(height: 20),
              const Row(children: [
                Icon(Icons.person, size: 18, color: AppColors.gold),
                SizedBox(width: 6),
                Text('选择驾驶员', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold)),
              ]),
              const SizedBox(height: 8),
              ...drivers.map((d) {
                final busyInfo = busyDrivers.where((b) => b['driver_id'] == d['id']).firstOrNull;
                return _driverTile(d, busyInfo: busyInfo);
              }),
              if (drivers.isEmpty) const Text('暂无可用驾驶员', style: TextStyle(color: AppColors.text2)),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_submitting ? '提交中...' : '确认指派', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildAppDetail(MachineryApplication app) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(app.applicationNo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold))),
          _tag(app.urgencyLabel, app.urgency == 'emergency' ? AppColors.danger : app.urgency == 'urgent' ? AppColors.warning : AppColors.text2),
          const SizedBox(width: 6),
          _tag(app.typeLabel, AppColors.text2),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 10),
        _detailRow(Icons.business_outlined, '申请部门', app.applicantDept),
        _detailRow(Icons.person_outline, '申请人', app.applicantName),
        _detailRow(Icons.phone_outlined, '联系电话', app.applicantPhone),
        const SizedBox(height: 4),
        _detailRow(Icons.build_outlined, '申请车型', app.vehicleType),
        _detailRow(Icons.calendar_today_outlined, '开始时间', app.scheduledStart),
        _detailRow(Icons.calendar_month_outlined, '结束时间', app.scheduledEnd),
        const SizedBox(height: 4),
        _detailRow(Icons.location_on_outlined, '作业地点', app.workLocation),
        if (app.workAltitude != null && app.workAltitude!.isNotEmpty)
          _detailRow(Icons.terrain_outlined, '作业点海拔', '${app.workAltitude}m'),
        _detailRow(Icons.assignment_outlined, '作业用途', app.workPurpose),
        if (app.isHazardous || (app.briefingMethod != null && app.briefingMethod!.isNotEmpty)) ...[
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),
          if (app.isHazardous)
            const Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Icon(Icons.warning_amber, size: 14, color: AppColors.danger),
                SizedBox(width: 4),
                Text('涉及危险作业', style: TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w500)),
              ]),
            ),
          if (app.briefingMethod != null && app.briefingMethod!.isNotEmpty)
            _detailRow(Icons.record_voice_over_outlined, '交底方式', app.briefingMethod!),
        ],
      ]),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: AppColors.text2),
        const SizedBox(width: 6),
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text))),
      ]),
    );
  }

  Widget _vehicleTile(Vehicle v, {bool isRecommended = false, Map<String, dynamic>? busyInfo}) {
    final isBusy = busyInfo != null;
    final selected = _selectedVehicleId == v.id;

    return GestureDetector(
      onTap: isBusy ? null : () => setState(() => _selectedVehicleId = v.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isBusy ? AppColors.danger.withValues(alpha: 0.06) : selected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isBusy ? AppColors.danger.withValues(alpha: 0.35) : selected ? AppColors.gold : isRecommended ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Row(children: [
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.block, size: 18, color: AppColors.danger),
            )
          else
            Radio<int?>(value: v.id, groupValue: _selectedVehicleId, onChanged: (val) => setState(() => _selectedVehicleId = val), activeColor: AppColors.gold, fillColor: WidgetStateProperty.all(AppColors.gold)),
          // 车辆基本信息
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(v.plateNumber, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isBusy ? AppColors.text2 : AppColors.text)),
                if (isRecommended && !isBusy) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                    child: const Text('推荐', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ),
                ],
                if (isBusy) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                    child: const Text('占用', style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${v.vehicleType}  ${v.model ?? ""}  ·  ¥${(v.hourlyRate ?? 0).toStringAsFixed(0)}/h', style: TextStyle(fontSize: 12, color: isBusy ? AppColors.text2 : AppColors.text2)),
            ]),
          ),
          // 繁忙信息显示在最右边
          if (isBusy)
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('驾驶员：${busyInfo!['driver_name'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                const SizedBox(height: 1),
                Text(busyInfo['application_no']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                const SizedBox(height: 1),
                Text('${busyInfo['applicant_name'] ?? '-'} · ${busyInfo['applicant_dept'] ?? '-'}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _driverTile(Map<String, dynamic> d, {Map<String, dynamic>? busyInfo}) {
    final driverId = d['id'] as int;
    final isBusy = busyInfo != null;
    final selected = _selectedDriverId == driverId;
    final name = d['name']?.toString() ?? '';
    final initial = name.isNotEmpty ? name[0] : '?';

    return GestureDetector(
      onTap: isBusy ? null : () => setState(() => _selectedDriverId = driverId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isBusy ? AppColors.danger.withValues(alpha: 0.06) : selected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isBusy ? AppColors.danger.withValues(alpha: 0.35) : selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Row(children: [
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.block, size: 18, color: AppColors.danger),
            )
          else
            Radio<int?>(value: driverId, groupValue: _selectedDriverId, onChanged: (val) => setState(() => _selectedDriverId = val), activeColor: AppColors.gold, fillColor: WidgetStateProperty.all(AppColors.gold)),
          // 头像圆圈 — busy时红色
          CircleAvatar(
            radius: 18,
            backgroundColor: isBusy ? AppColors.danger.withValues(alpha: 0.2) : AppColors.gold.withValues(alpha: 0.15),
            child: Text(initial, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isBusy ? AppColors.danger : AppColors.gold)),
          ),
          const SizedBox(width: 10),
          // 姓名+电话
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isBusy ? AppColors.text2 : AppColors.text)),
              if (d['phone'] != null) Text(d['phone'].toString(), style: TextStyle(fontSize: 12, color: isBusy ? AppColors.text2 : AppColors.text2)),
            ]),
          ),
          // 繁忙信息显示在最右边
          if (isBusy)
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('车辆编号：${busyInfo!['plate_number'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                const SizedBox(height: 1),
                Text('订单：${busyInfo['application_no']?.toString() ?? '-'}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
                const SizedBox(height: 1),
                Text('${busyInfo['applicant_name'] ?? '-'} · ${busyInfo['applicant_dept'] ?? '-'}', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
              ]),
            ),
        ]),
      ),
    );
  }
}
