import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';
import '../../providers/repair_provider.dart';

/// 试车验收页面 — 驾驶员确认维修完成后试车验收
class TrialAcceptPage extends ConsumerStatefulWidget {
  final int orderId;

  const TrialAcceptPage({super.key, required this.orderId});

  @override
  ConsumerState<TrialAcceptPage> createState() => _TrialAcceptPageState();
}

class _TrialAcceptPageState extends ConsumerState<TrialAcceptPage> {
  late final TextEditingController _contentCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(
      text: '故障已消除，试车目前无问题，可以验收',
    );
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      _snack('请填写试车验收意见');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(repairActionsProvider.notifier).verifyOrder(
            widget.orderId,
            content: content,
          );
      if (mounted) {
        _snack('验收通过，工单已闭环');
        ref.invalidate(orderDetailProvider(widget.orderId));
        context.pop();
      }
    } catch (e) {
      if (mounted) _snack('${e}'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('试车验收'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 提示卡片
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.drive_eta, color: AppColors.gold, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '维修已完成，请试车确认车辆恢复正常，填写验收意见后点击通过验收闭环工单。',
                      style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 验收意见
            const Text('试车验收意见', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              maxLines: 6,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: '请描述试车结果...',
                hintStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 通过验收按钮
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, size: 20),
                label: Text(_submitting ? '提交中...' : '通过验收', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
