import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/safety_provider.dart';
import '../../services/http_client.dart';
import '../../config/api_config.dart';

import '../../config/color_constants.dart';

class AssessmentFormPage extends ConsumerStatefulWidget {
  const AssessmentFormPage({super.key});

  @override
  ConsumerState<AssessmentFormPage> createState() => _AssessmentFormPageState();
}

class _AssessmentFormPageState extends ConsumerState<AssessmentFormPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int? _targetId;
  String _assessType = '通报';
  final List<String> _photos = [];
  bool _uploading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final client = HttpClient();
      final bytes = await xfile.readAsBytes();
      final resp = await client.uploadBytes('/upload/single', bytes, xfile.name, 'file');
      if (resp.isSuccess && resp.data != null) {
        final url = (resp.data as Map<String, dynamic>)['url'] ?? '';
        if (url.isNotEmpty) setState(() => _photos.add(url));
      }
    } catch (_) {}
    setState(() => _uploading = false);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写标题')));
      return;
    }
    if (_targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择被考核人')));
      return;
    }
    try {
      await ref.read(safetyActionsProvider.notifier).issueAssessment(
        targetId: _targetId!,
        title: title,
        content: _contentController.text.trim(),
        assessType: _assessType,
        photos: _photos.isNotEmpty ? _photos : null,
        assessDate: _selectedDate.toIso8601String().split('T')[0],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通报已下发')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final actionsState = ref.watch(safetyActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('下发考核通报'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('被考核人 *'),
            const SizedBox(height: 4),
            usersAsync.when(
              loading: () => const SizedBox(
                height: 42,
                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
              ),
              error: (_, __) => _input(TextEditingController(), '加载失败', enabled: false),
              data: (users) => _userDropdown(users),
            ),
            const SizedBox(height: 14),

            _label('考核类型'),
            const SizedBox(height: 4),
            _typeSelector(),
            const SizedBox(height: 14),

            _label('标题 *'),
            const SizedBox(height: 4),
            _input(_titleController, '如：6月安全隐患排查表扬'),
            const SizedBox(height: 14),

            _label('考核日期'),
            const SizedBox(height: 4),
            _datePicker(),
            const SizedBox(height: 14),

            _label('内容'),
            const SizedBox(height: 4),
            TextField(
              controller: _contentController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: _inputDecoration('请详细描述考核内容...'),
            ),
            const SizedBox(height: 14),

            _label('相关照片'),
            const SizedBox(height: 4),
            if (_photos.isNotEmpty) ...[
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _photos.map((url) => _photoPreview(url)).toList(),
              ),
              const SizedBox(height: 8),
            ],
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2e38),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate, size: 16, color: AppColors.text2),
                    const SizedBox(width: 4),
                    Text(_uploading ? '上传中...' : '选择照片', style: const TextStyle(fontSize: 13, color: AppColors.text2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: actionsState.loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: actionsState.loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                    : const Text('下发通报', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, color: AppColors.text2, fontWeight: FontWeight.w500));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.text2, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF2a2e38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
    );
  }

  Widget _datePicker() {
    final display = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: AppColors.bg, surface: AppColors.surface),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2e38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.text2),
            const SizedBox(width: 8),
            Text(display, style: const TextStyle(color: AppColors.text, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, {bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: _inputDecoration(hint),
    );
  }

  Widget _typeSelector() {
    final types = ['表扬', '通报', '警告', '处罚'];
    return Wrap(
      spacing: 8,
      children: types.map((t) {
        final selected = _assessType == t;
        Color color;
        switch (t) {
          case '表扬': color = const Color(0xFF5a9e5f); break;
          case '通报': color = const Color(0xFFd4a017); break;
          case '警告':
          case '处罚': color = const Color(0xFFe05555); break;
          default: color = AppColors.text2;
        }
        return GestureDetector(
          onTap: () => setState(() => _assessType = t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.15) : const Color(0xFF2a2e38),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selected ? color : AppColors.border),
            ),
            child: Text(t, style: TextStyle(fontSize: 13, color: selected ? color : AppColors.text2, fontWeight: FontWeight.w500)),
          ),
        );
      }).toList(),
    );
  }

  Widget _userDropdown(List<Map<String, dynamic>> users) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2e38),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<int?>(
        value: _targetId,
        isExpanded: true,
        dropdownColor: const Color(0xFF2a2e38),
        style: const TextStyle(color: AppColors.text, fontSize: 14),
        underline: const SizedBox(),
        hint: const Text('请选择被考核人', style: TextStyle(color: AppColors.text2, fontSize: 14)),
        items: users.map((u) => DropdownMenuItem<int>(
              value: u['id'] as int,
              child: Text('${u['name']}（${u['role']}）', style: const TextStyle(color: AppColors.text)),
            )).toList(),
        onChanged: (v) => setState(() => _targetId = v),
      ),
    );
  }

  Widget _photoPreview(String url) {
    final fullUrl = url.startsWith('http') ? url : ApiConfig.fileUrl(url);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(fullUrl, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0, right: 0,
          child: GestureDetector(
            onTap: () => setState(() => _photos.remove(url)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Color(0xFFe05555), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4))),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
