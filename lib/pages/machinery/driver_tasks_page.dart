import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/machinery.dart';
import '../../providers/machinery_provider.dart';
import '../../widgets/silent_auto_refresh.dart';

import '../../config/color_constants.dart';

class DriverTasksPage extends ConsumerStatefulWidget {
  const DriverTasksPage({super.key});

  @override
  ConsumerState<DriverTasksPage> createState() => _DriverTasksPageState();
}

class _DriverTasksPageState extends ConsumerState<DriverTasksPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('派车任务'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.text2,
          tabs: const [Tab(text: '当前任务'), Tab(text: '历史任务')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // 当前任务
          _buildTaskList(ref.watch(driverTasksProvider)),
          // 历史任务
          _buildTaskList(ref.watch(driverHistoryProvider)),
        ],
      ),
    );
  }

  Widget _buildTaskList(AsyncValue<List<MachineryApplication>> async) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
      data: (list) => list.isEmpty
          ? const Center(child: Text('暂无任务', style: TextStyle(color: AppColors.text2)))
          : SilentAutoRefresh(
              intervalSeconds: 20,
              onRefresh: (r) {
                r.invalidate(driverTasksProvider);
                r.invalidate(driverHistoryProvider);
              },
              child: RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async {
                  ref.invalidate(driverTasksProvider);
                  ref.invalidate(driverHistoryProvider);
                },
                child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _buildCard(context, list[i]),
              ),
            ),
          ),
    );
  }

  Widget _buildCard(BuildContext context, MachineryApplication app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: () => context.push('/machinery/detail/${app.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(app.applicationNo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
            if (app.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: const Text('进行中', style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w500)),
              ),
            if (app.isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF5a9e5f).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: const Text('已完成', style: TextStyle(fontSize: 11, color: Color(0xFF5a9e5f), fontWeight: FontWeight.w500)),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _infoRow(Icons.person, '申请方：${app.applicantDept} ${app.applicantName}')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _infoRow(Icons.phone, app.applicantPhone),
            const SizedBox(width: 12),
            _infoRow(Icons.directions_car, app.vehicleDisplay),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _infoRow(Icons.location_on, app.workLocation),
            const SizedBox(width: 12),
            _infoRow(Icons.access_time, '${app.scheduledStart} ~ ${app.scheduledEnd}'),
          ]),
          if (app.isCompleted && app.totalCost != null) ...[
            const SizedBox(height: 4),
            Text('费用：¥${app.totalCost!.toStringAsFixed(2)} · ${(app.workingHours ?? 0).toStringAsFixed(2)}h',
                style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.text2),
      const SizedBox(width: 3),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
    ]);
  }
}
