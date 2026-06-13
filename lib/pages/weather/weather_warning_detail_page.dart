import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/weather.dart';
import '../../providers/auth_provider.dart';
import '../../providers/weather_provider.dart';

import '../../config/color_constants.dart';

class WeatherWarningDetailPage extends ConsumerStatefulWidget {
  final int warningId;
  const WeatherWarningDetailPage({super.key, required this.warningId});

  @override
  ConsumerState<WeatherWarningDetailPage> createState() => _WeatherWarningDetailPageState();
}

class _WeatherWarningDetailPageState extends ConsumerState<WeatherWarningDetailPage> {
  WeatherWarning? _w;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await ref.read(weatherServiceProvider).getWarningDetail(widget.warningId);
    if (mounted) setState(() { _w = w; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canResolve = user?.role == 'admin' || user?.role == 'safety_officer' || user?.role == 'dispatcher';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('预警详情'),
        backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _w == null
              ? const Center(child: Text('预警不存在', style: TextStyle(color: AppColors.text2)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: _buildContent(canResolve),
                ),
    );
  }

  Widget _buildContent(bool canResolve) {
    final w = _w!;
    final color = _levelColor(w.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预警级别大标签
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(levelEmoji[w.level] ?? '', style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 4),
              Text(levelLabels[w.level] ?? w.level,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 信息表
        _infoRow('预警类型', '${weatherIcons[w.weatherType] ?? ''} ${weatherLabels[w.weatherType] ?? w.weatherType}'),
        _infoRow('区域', w.zoneName ?? '-'),
        _infoRow('状态', w.status == 'active' ? '活跃' : (w.status == 'acknowledged' ? '已确认' : '已解除')),
        _infoRow('创建时间', w.createdAt ?? '-'),
        if (w.resolvedAt != null) _infoRow('解除时间', w.resolvedAt!),
        if (w.description != null && w.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('描述', style: TextStyle(fontSize: 12, color: AppColors.text2)),
          const SizedBox(height: 4),
          Text(w.description!, style: const TextStyle(fontSize: 14, color: AppColors.text)),
        ],

        const SizedBox(height: 24),

        // 操作按钮
        if (w.status != 'resolved') ...[
          Row(
            children: [
              if (w.status == 'active')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acknowledge(),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('确认预警'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (w.status == 'active') const SizedBox(width: 10),
              if (canResolve)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resolve(),
                    icon: const Icon(Icons.cloud_done, size: 16),
                    label: const Text('解除预警'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('返回'),
            style: TextButton.styleFrom(foregroundColor: AppColors.text2),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.text))),
        ],
      ),
    );
  }

  Future<void> _acknowledge() async {
    try {
      await ref.read(weatherActionsProvider.notifier).acknowledgeWarning(widget.warningId);
      if (mounted) { _load(); ref.invalidate(weatherWarningsProvider); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _resolve() async {
    try {
      await ref.read(weatherActionsProvider.notifier).resolveWarning(widget.warningId);
      if (mounted) { _load(); ref.invalidate(weatherWarningsProvider); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'red': return AppColors.danger;
      case 'orange': return AppColors.warning;
      case 'yellow': return const Color(0xFFd4a017);
      case 'blue': return const Color(0xFF4a90d9);
      default: return AppColors.text2;
    }
  }
}
