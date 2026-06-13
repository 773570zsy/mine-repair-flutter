import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/api_config.dart';
import '../../models/vehicle_archive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_archive_provider.dart';

import '../../config/color_constants.dart';

class ArchiveDetailPage extends ConsumerStatefulWidget {
  final String plateNumber;
  const ArchiveDetailPage({super.key, required this.plateNumber});

  @override
  ConsumerState<ArchiveDetailPage> createState() => _ArchiveDetailPageState();
}

class _ArchiveDetailPageState extends ConsumerState<ArchiveDetailPage> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(vehicleArchiveDetailProvider(widget.plateNumber));
    final user = ref.watch(authProvider).user;
    final canEdit = user?.role == 'admin' || user?.role == 'dispatcher';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.plateNumber),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
        data: (v) {
          if (v == null) {
            return const Center(child: Text('车辆档案不存在', style: TextStyle(color: AppColors.text2)));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildPhotoCarousel(v),
                const SizedBox(height: 16),
                _buildInfoTable(v),
                const SizedBox(height: 20),
                _buildActionButtons(context, v, canEdit),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== 照片轮播 ====================

  Widget _buildPhotoCarousel(VehicleArchive v) {
    if (v.photos.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car, size: 48, color: AppColors.border),
              SizedBox(height: 8),
              Text('暂无外观照片', style: TextStyle(color: AppColors.text2, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final photos = v.photos.map((p) => ApiConfig.fileUrl(p)).toList();

    // 确保索引不越界
    if (_photoIndex >= photos.length) _photoIndex = 0;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 照片
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Image.network(
              photos[_photoIndex],
              key: ValueKey(_photoIndex),
              width: double.infinity,
              height: 280,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface2,
                child: const Center(child: Icon(Icons.broken_image, color: AppColors.text2, size: 48)),
              ),
            ),
          ),

          // 左右箭头
          if (photos.length > 1) ...[
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _photoIndex = (_photoIndex - 1 + photos.length) % photos.length),
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Center(child: Icon(Icons.chevron_left, color: Colors.white, size: 24)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _photoIndex = (_photoIndex + 1) % photos.length),
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Center(child: Icon(Icons.chevron_right, color: Colors.white, size: 24)),
                  ),
                ),
              ),
            ),
          ],

          // 底部圆点
          if (photos.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: photos.asMap().entries.map((e) {
                  final active = e.key == _photoIndex;
                  return Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? Colors.white : Colors.white38,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== 信息表格 ====================

  Widget _buildInfoTable(VehicleArchive v) {
    final useHours = v.useHoursMaintenance;
    final useKm = v.useKmMaintenance;

    final rows = <_InfoRow>[
      _row('内部编号', v.plateNumber),
      _row('所属部门', v.department ?? '总调度室'),
      _row('类型', v.vehicleType ?? '-'),
      _row('具体型号', v.model ?? '-'),
      _row('出厂日期', v.manufactureDate ?? '-'),
      _row('购买日期', v.purchaseDate ?? '-'),
      _row('车辆资产净值', v.assetValue > 0 ? '¥${v.assetValue.toStringAsFixed(2)}' : '-'),
      _row('小时单价', v.hourlyRate > 0 ? '¥${v.hourlyRate.toStringAsFixed(2)}/h' : '-'),
      _row('车辆识别代码(VIN)', v.vin ?? '-'),
      _row('保险到期日', v.insuranceExpiry ?? '-'),
      _row('年检日期', v.inspectionDate ?? '-'),
    ];

    // 工时保养（仅当活跃时显示）
    if (useHours) {
      final hStatus = v.hoursStatus;
      final hColor = _statusColor(hStatus);
      rows.addAll([
        _row('保养间隔', '${v.maintenanceInterval}h'),
        _row('下次保养工时', '${v.nextMaintenanceHours}h'),
        _row('当前工时', '${v.currentHours.toInt()}h  ', extraColor: hColor, extraText: '($hStatus)'),
      ]);
    }

    // 公里保养（仅当活跃时显示）
    if (useKm) {
      final kmStatus = v.kmStatus;
      final kmColor = _statusColor(kmStatus);
      rows.addAll([
        _row('保养间隔', '${v.maintenanceIntervalKm}km'),
        _row('下次保养公里', '${v.nextMaintenanceKm}km'),
        _row('当前公里', '${v.currentKm}km  ', extraColor: kmColor, extraText: '($kmStatus)'),
      ]);
    }

    // 都没设置
    if (!useHours && !useKm) {
      rows.add(_row('保养设置', '未设置'));
    }

    rows.addAll([
      _row('行为监控', v.hasBehaviorMonitor ? '有' : '无'),
      _row('360环影', v.has360Camera ? '有' : '无'),
      _row('当前驾驶员', v.driverName ?? '无'),
      _row('车辆状态', v.vehicleStatus == 'repairing' ? '维修中' : '正常',
          valueColor: v.vehicleStatus == 'repairing' ? AppColors.warning : AppColors.success),
    ]);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: i < rows.length - 1
                  ? const Border(bottom: BorderSide(color: AppColors.border))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(r.label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: r.value, style: TextStyle(fontSize: 14, color: r.valueColor ?? AppColors.text)),
                        if (r.extraText != null)
                          TextSpan(text: r.extraText, style: TextStyle(fontSize: 14, color: r.extraColor ?? AppColors.text, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== 操作按钮 ====================

  Widget _buildActionButtons(BuildContext context, VehicleArchive v, bool canEdit) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (canEdit) ...[
          ElevatedButton.icon(
            onPressed: () => context.pushNamed('vehicle-archive-edit', pathParameters: {'plateNumber': v.plateNumber}),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('编辑'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          if (v.useHoursMaintenance)
            ElevatedButton.icon(
              onPressed: () => _maintenanceDone(v),
              icon: const Icon(Icons.build_circle, size: 16),
              label: Text('已保养 (+${v.maintenanceInterval}h)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          if (v.useKmMaintenance)
            ElevatedButton.icon(
              onPressed: () => _maintenanceDoneKm(v),
              icon: const Icon(Icons.speed, size: 16),
              label: Text('已保养 (+${v.maintenanceIntervalKm}km)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
        ],
        OutlinedButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('返回列表'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text2,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Future<void> _maintenanceDone(VehicleArchive v) async {
    try {
      await ref.read(vehicleArchiveActionsProvider.notifier).maintenanceDone(v.plateNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保养已完成'), backgroundColor: AppColors.success),
        );
        // Refresh detail
        ref.invalidate(vehicleArchiveDetailProvider(widget.plateNumber));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _maintenanceDoneKm(VehicleArchive v) async {
    try {
      await ref.read(vehicleArchiveActionsProvider.notifier).maintenanceDoneKm(v.plateNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保养已完成'), backgroundColor: AppColors.success),
        );
        ref.invalidate(vehicleArchiveDetailProvider(widget.plateNumber));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case '保养过期': return AppColors.danger;
      case '即将保养': return AppColors.warning;
      case '正常': return AppColors.success;
      default: return AppColors.text2;
    }
  }
}

/// 表格行数据
class _InfoRow {
  final String label;
  final String value;
  final Color? valueColor;
  final String? extraText;
  final Color? extraColor;

  const _InfoRow(this.label, this.value, {this.valueColor, this.extraText, this.extraColor});
}

_InfoRow _row(String label, String value, {Color? valueColor, String? extraText, Color? extraColor}) {
  return _InfoRow(label, value, valueColor: valueColor, extraText: extraText, extraColor: extraColor);
}
