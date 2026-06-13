import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../models/vehicle_archive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/vehicle_archive_provider.dart';
import '../../services/download_service.dart';

class ArchiveListPage extends ConsumerStatefulWidget {
  const ArchiveListPage({super.key});

  @override
  ConsumerState<ArchiveListPage> createState() => _ArchiveListPageState();
}

class _ArchiveListPageState extends ConsumerState<ArchiveListPage> {
  String? _deptFilter;
  String? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final filter = ArchiveFilter(department: _deptFilter, vehicleType: _typeFilter);
    final archivesAsync = ref.watch(filteredArchiveListProvider(filter));
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == 'admin' || user?.role == 'dispatcher';

    // 下拉选项（initialised once）
    final deptsAsync = ref.watch(archiveDepartmentsProvider);
    final typesAsync = ref.watch(archiveVehicleTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('车辆管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          // 导出档案明细
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 20, color: AppColors.gold),
            tooltip: '导出档案明细',
            onPressed: () => _exportArchives(),
          ),
          if (isAdmin) ...[
            IconButton(icon: const Icon(Icons.add, color: AppColors.gold, size: 22), tooltip: '添加车辆', onPressed: () => context.push('/vehicle-archive/add')),
            IconButton(icon: const Icon(Icons.link, color: AppColors.gold, size: 22), tooltip: '绑定驾驶员', onPressed: () => _showBindDialog(context)),
          ],
        ],
      ),
      body: Column(children: [
        // ===== 筛选栏 =====
        _buildFilterBar(deptsAsync, typesAsync),
        const Divider(color: AppColors.border, height: 1),
        // ===== 车辆列表 =====
        Expanded(child: archivesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: AppColors.danger))),
          data: (archives) {
            if (archives.isEmpty) {
              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.folder_open, size: 64, color: AppColors.text2),
                  const SizedBox(height: 12),
                  const Text('暂无车辆', style: TextStyle(color: AppColors.text2, fontSize: 16)),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/vehicle-archive/add'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加车辆'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
                    ),
                  ],
                ]),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(filteredArchiveListProvider(filter));
                ref.invalidate(archiveDepartmentsProvider);
                ref.invalidate(archiveVehicleTypesProvider);
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 8.0,
                ),
                itemCount: archives.length,
                itemBuilder: (_, i) => _buildCard(context, archives[i]),
              ),
            );
          },
        )),
      ]),
    );
  }

  // ===== 筛选栏 =====
  Widget _buildFilterBar(AsyncValue<List<String>> deptsAsync, AsyncValue<List<String>> typesAsync) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.surface,
      child: Row(children: [
        // 归属部门
        Expanded(
          child: deptsAsync.when(
            loading: () => _ddLoading(),
            error: (_, __) => _ddError(),
            data: (depts) => _dropdown('部门', depts, _deptFilter, (v) => setState(() => _deptFilter = v)),
          ),
        ),
        const SizedBox(width: 6),
        // 车型
        Expanded(
          child: typesAsync.when(
            loading: () => _ddLoading(),
            error: (_, __) => _ddError(),
            data: (types) => _dropdown('车型', types, _typeFilter, (v) => setState(() => _typeFilter = v)),
          ),
        ),
      ]),
    );
  }

  Widget _ddLoading() => Container(
    height: 34, alignment: Alignment.center,
    child: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
  );

  Widget _ddError() => Container(
    height: 34, alignment: Alignment.center,
    child: const Text('加载失败', style: TextStyle(color: AppColors.text2, fontSize: 11)),
  );

  Widget _dropdown(String hint, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: AppColors.text2, fontSize: 12)),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('全部$hint', style: const TextStyle(color: AppColors.text2, fontSize: 12))),
            ...items.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t, style: const TextStyle(color: AppColors.text, fontSize: 12)))),
          ],
          onChanged: onChanged,
          dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 18),
          isDense: true,
        ),
      ),
    );
  }

  // ===== 紧凑卡片（单行居中） =====
  Widget _buildCard(BuildContext context, VehicleArchive v) {
    final statusColor = v.vehicleStatus == 'repairing' ? AppColors.warning : (v.vehicleStatus == 'scrapped' ? AppColors.danger : AppColors.success);
    final dept = (v.department != null && v.department!.isNotEmpty) ? v.department! : '';
    return GestureDetector(
      onTap: () => context.pushNamed('vehicle-archive-detail', pathParameters: {'plateNumber': v.plateNumber}),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Flexible(child: Text(v.plateNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text), overflow: TextOverflow.ellipsis)),
          if (dept.isNotEmpty) ...[
            const SizedBox(width: 4),
            Flexible(child: Text(dept, style: const TextStyle(fontSize: 14, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
          ],
          const SizedBox(width: 4),
          Flexible(child: Text(v.vehicleType ?? '', style: const TextStyle(fontSize: 14, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  // ===== 导出 =====
  Future<void> _exportArchives() async {
    try {
      _snack('正在生成车辆档案明细...');
      final path = await DownloadService.instance.downloadXlsx(
        '/vehicle-archives/export-xlsx',
        {
          if (_deptFilter != null) 'department': _deptFilter,
          if (_typeFilter != null) 'vehicle_type': _typeFilter,
        },
        '车辆档案明细.xlsx',
      );
      if (mounted) _snack(path != null ? '已保存: $path' : '导出成功，请检查浏览器下载');
    } catch (e) {
      if (mounted) _snack('导出失败: $e');
    }
  }

  // ---- 管理操作 ----
  void _showBindDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (c) => _BindDriverDialog(onSaved: () => ref.invalidate(filteredArchiveListProvider(ArchiveFilter()))));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
}

/// 绑定驾驶员弹窗
class _BindDriverDialog extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _BindDriverDialog({required this.onSaved});

  @override
  ConsumerState<_BindDriverDialog> createState() => _BindDriverDialogState();
}

class _BindDriverDialogState extends ConsumerState<_BindDriverDialog> {
  int? _driverId, _vehicleId;
  List<Map<String, dynamic>> _drivers = [], _vehicles = [];
  bool _loading = true, _saving = false;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      final srv = ref.read(adminServiceProvider);
      final drivers = await srv.getDriverList();
      final vehicles = await srv.getVehicles();
      _drivers = drivers.map((d) => {'id': d.id, 'name': d.name, 'phone': d.phone}).toList();
      _vehicles = vehicles.map((v) => {'id': v.id, 'name': v.plateNumber}).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _bind() async {
    if (_driverId == null || _vehicleId == null) { _snack('请选择驾驶员和车辆'); return; }
    setState(() => _saving = true);
    try {
      await ref.read(adminActionsProvider).bindDriver(driverId: _driverId!, vehicleId: _vehicleId!);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) { _snack('$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('绑定驾驶员到车辆', style: TextStyle(color: AppColors.text, fontSize: 16)),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
          : Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int?>(value: _vehicleId, items: _vehicles.map((v) => DropdownMenuItem(value: v['id'] as int, child: Text(v['name'] as String, style: const TextStyle(color: AppColors.text, fontSize: 13)))).toList(), onChanged: (v) => _vehicleId = v, decoration: _ddDeco('选择车辆'), dropdownColor: AppColors.surface2),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(value: _driverId, items: _drivers.map((d) => DropdownMenuItem(value: d['id'] as int, child: Text('${d['name']} (${d['phone']})', style: const TextStyle(color: AppColors.text, fontSize: 13)))).toList(), onChanged: (v) => _driverId = v, decoration: _ddDeco('选择驾驶员'), dropdownColor: AppColors.surface2),
            ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
        ElevatedButton(onPressed: _saving ? null : _bind, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg), child: const Text('绑定', style: TextStyle(fontSize: 13))),
      ],
    );
  }

  InputDecoration _ddDeco(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13), border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)));
}
