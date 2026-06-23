import 'package:flutter/material.dart';
import '../config/color_constants.dart';
import '../services/update_service.dart';

/// 应用更新弹窗 —— 显示更新日志 + 下载进度 + 安装
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  /// 检查并弹出更新提示
  static Future<void> checkAndShow(BuildContext context) async {
    final info = await UpdateService().checkOnce();
    if (info == null || !context.mounted) return;

    if (info.forceUpdate) {
      // 强制更新 — 不可关闭
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(info: info),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => UpdateDialog(info: info),
      );
    }
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() { _downloading = true; _error = null; });

    try {
      final path = await UpdateService().downloadApk(
        widget.info.downloadUrl,
        (p) => setState(() => _progress = p),
      );
      await UpdateService().installApk(path);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(children: [
        const Icon(Icons.system_update, color: AppColors.gold),
        const SizedBox(width: 8),
        Text('发现新版本 ${info.versionName}',
            style: const TextStyle(color: AppColors.text, fontSize: 17)),
      ]),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 更新日志
            const Text('更新内容：', style: TextStyle(color: AppColors.text2, fontSize: 13)),
            const SizedBox(height: 6),
            Text(info.changelog,
                style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.5)),

            if (_downloading) ...[
              const SizedBox(height: 16),
              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppColors.surface2,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _progress > 0 ? '下载中 ${(_progress * 100).toStringAsFixed(0)}%' : '准备下载...',
                style: const TextStyle(color: AppColors.text2, fontSize: 12),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text('下载失败: $_error',
                  style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        if (!widget.info.forceUpdate && !_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后更新', style: TextStyle(color: AppColors.text2)),
          ),
        if (_error != null)
          TextButton(
            onPressed: _downloadAndInstall,
            child: const Text('重试', style: TextStyle(color: AppColors.gold)),
          ),
        if (!_downloading && _error == null)
          ElevatedButton(
            onPressed: _downloadAndInstall,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
            ),
            child: const Text('立即更新'),
          ),
      ],
    );
  }
}
