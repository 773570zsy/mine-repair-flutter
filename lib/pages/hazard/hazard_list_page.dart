import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/hazard_provider.dart';
import '../../models/hazard.dart';

// 复用维修模块的颜色常量
import '../../config/color_constants.dart';

class HazardListPage extends ConsumerStatefulWidget {
  const HazardListPage({super.key});

  @override
  ConsumerState<HazardListPage> createState() => _HazardListPageState();
}

class _HazardListPageState extends ConsumerState<HazardListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('隐患管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.text2,
          tabs: const [
            Tab(text: '处理中'),
            Tab(text: '已闭环'),
            Tab(text: '全部'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActiveHazardTab(),
          _HazardTabContent(statusFilter: 'verified'),
          _HazardTabContent(statusFilter: null),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => context.push('/hazard/report'),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HazardTabContent extends ConsumerWidget {
  final String? statusFilter;

  const _HazardTabContent({required this.statusFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazardsAsync = ref.watch(hazardListProvider(statusFilter));

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async => ref.invalidate(hazardListProvider(statusFilter)),
      child: hazardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('加载失败', style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(hazardListProvider(statusFilter)),
                child: const Text('重试', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
        data: (hazards) {
          if (hazards.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 48, color: AppColors.text2),
                  SizedBox(height: 8),
                  Text('暂无隐患记录', style: TextStyle(color: AppColors.text2, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: hazards.length,
            itemBuilder: (context, i) => _HazardCard(hazard: hazards[i]),
          );
        },
      ),
    );
  }
}

/// 处理中 tab：后端不支持 status=active，取全部并在客户端过滤非 verified
class _ActiveHazardTab extends ConsumerWidget {
  const _ActiveHazardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazardsAsync = ref.watch(hazardListProvider(null));

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async => ref.invalidate(hazardListProvider(null)),
      child: hazardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('加载失败', style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(hazardListProvider(null)),
                child: const Text('重试', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
        data: (hazards) {
          final active = hazards.where((h) => h.status != 'verified').toList();
          if (active.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 48, color: AppColors.text2),
                  SizedBox(height: 8),
                  Text('暂无处理中的隐患', style: TextStyle(color: AppColors.text2, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: active.length,
            itemBuilder: (context, i) => _HazardCard(hazard: active[i]),
          );
        },
      ),
    );
  }
}

class _HazardCard extends StatelessWidget {
  final Hazard hazard;
  const _HazardCard({required this.hazard});

  Color _severityColor() {
    switch (hazard.severity) {
      case '低':
        return AppColors.success;
      case '一般':
        return AppColors.warning;
      case '高':
      case '紧急':
        return AppColors.danger;
      default:
        return AppColors.text2;
    }
  }

  Color _statusColor() {
    switch (hazard.status) {
      case 'reported':
      case 'assigned':
        return AppColors.warning;
      case 'rectifying':
        return const Color(0xFF7a8a9a);
      case 'completed':
        return AppColors.warning;
      case 'verified':
        return AppColors.success;
      default:
        return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/hazard/detail/${hazard.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(hazard.hazardNo,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _severityColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _severityColor().withValues(alpha: 0.3)),
                  ),
                  child: Text(hazard.severity,
                      style: TextStyle(fontSize: 10, color: _severityColor(), fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _statusColor().withValues(alpha: 0.3)),
                  ),
                  child: Text(hazard.statusLabel,
                      style: TextStyle(fontSize: 10, color: _statusColor(), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 12, color: AppColors.text2),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(hazard.location.isNotEmpty ? hazard.location : '未指定地点',
                      style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(hazard.description,
                style: const TextStyle(fontSize: 12, color: AppColors.text2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(hazard.reporterName ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                if (hazard.responsibleName != null) ...[
                  const Text(' → ', style: TextStyle(fontSize: 11, color: AppColors.text2)),
                  Text(hazard.responsibleName!,
                      style: const TextStyle(fontSize: 11, color: AppColors.gold)),
                ],
                const Spacer(),
                if (hazard.deadline.isNotEmpty)
                  Text(hazard.deadline,
                      style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
