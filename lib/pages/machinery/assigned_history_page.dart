import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/machinery.dart';
import '../../services/machinery_service.dart';
import '../../config/color_constants.dart';

/// 最近已指派工单历史（最近10条）
class AssignedHistoryPage extends StatefulWidget {
  const AssignedHistoryPage({super.key});

  @override
  State<AssignedHistoryPage> createState() => _AssignedHistoryPageState();
}

class _AssignedHistoryPageState extends State<AssignedHistoryPage> {
  late Future<List<MachineryApplication>> _future;

  @override
  void initState() {
    super.initState();
    _future = MachineryService().getAllApplications(status: 'assigned');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('历史指派'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: FutureBuilder<List<MachineryApplication>>(
        future: _future,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}', style: const TextStyle(color: AppColors.danger)));
          }
          final all = snapshot.data ?? [];
          final list = all.take(10).toList();
          if (list.isEmpty) {
            return const Center(child: Text('暂无已指派工单', style: TextStyle(color: AppColors.text2, fontSize: 14)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildCard(list[i]),
          );
        },
      ),
    );
  }

  Widget _buildCard(MachineryApplication app) {
    return GestureDetector(
      onTap: () => context.push('/machinery/detail/${app.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(app.applicationNo, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2980b9).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2980b9).withValues(alpha: 0.3)),
              ),
              child: const Text('已指派', style: TextStyle(color: Color(0xFF2980b9), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 6),
          _infoRow('申请部门', app.applicantDept),
          _infoRow('申请人', app.applicantName),
          _infoRow('车辆类型', app.vehicleType),
          _infoRow('作业地点', app.workLocation),
          if (app.assignedPlate != null && app.assignedPlate!.isNotEmpty) ...[
            _infoRow('指派车辆', app.vehicleDisplay),
            _infoRow('指派驾驶员', app.driverName ?? '-', valueColor: AppColors.gold),
          ],
          _infoRow('用车时间', app.workTimeDisplay),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 12))),
        Expanded(child: Text(value, style: TextStyle(color: valueColor ?? AppColors.text, fontSize: 12))),
      ]),
    );
  }
}
