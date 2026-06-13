import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';

import '../../config/color_constants.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(backupListProvider);
    final actions = ref.read(adminActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('数据备份'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _backup(actions),
            icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.gold),
            label: const Text('立即备份', style: TextStyle(color: AppColors.gold, fontSize: 13)),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.warning.withValues(alpha: 0.05),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.warning, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('最多保留7个备份，恢复后将自动重启服务', style: TextStyle(color: AppColors.warning, fontSize: 12))),
          ]),
        ),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (backups) => backups.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.save_alt, size: 48, color: AppColors.text2),
                  SizedBox(height: 8),
                  Text('暂无备份', style: TextStyle(color: AppColors.text2)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: backups.length,
                  itemBuilder: (ctx, i) => _backupRow(backups[i], actions),
                ),
        )),
      ]),
    );
  }

  Widget _backupRow(dynamic b, dynamic actions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.save, color: AppColors.gold, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 4),
          Row(children: [
            _tag(b.size, AppColors.warning),
            const SizedBox(width: 10),
            _tag(b.mtime.length >= 16 ? b.mtime.substring(0, 16).replaceAll('T', ' ') : b.mtime, AppColors.text2),
          ]),
        ])),
        TextButton(
          onPressed: () => _confirmRestore(b.name, actions),
          child: const Text('恢复', style: TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _tag(String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(text, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }

  void _confirmRestore(String filename, dynamic actions) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认恢复', style: TextStyle(color: AppColors.text)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('恢复后将覆盖当前数据库，服务需重启生效。', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          const SizedBox(height: 8),
          Text(filename, style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx);
            try {
              final msg = await actions.restoreBackup(filename);
              _snack(msg, AppColors.success);
              ref.invalidate(backupListProvider);
            } catch (e) { _snack('$e', AppColors.danger); }
          }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white), child: const Text('确认恢复', style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _backup(dynamic actions) async {
    try {
      final msg = await actions.backupDb();
      _snack(msg, AppColors.success);
      ref.invalidate(backupListProvider);
    } catch (e) { _snack('$e', AppColors.danger); }
  }

  void _snack(String m, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: bg));
  }
}
