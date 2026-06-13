import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/color_constants.dart';
import '../../config/api_config.dart';
import '../../providers/external_repair_provider.dart';
import '../../services/http_client.dart';

/// 外部报修页面
class ReportExternalPage extends ConsumerStatefulWidget {
  const ReportExternalPage({super.key});

  @override
  ConsumerState<ReportExternalPage> createState() => _ReportExternalPageState();
}

class _ReportExternalPageState extends ConsumerState<ReportExternalPage> {
  final _vehicleNameCtrl = TextEditingController();
  final _deptNameCtrl = TextEditingController();
  final _faultDescCtrl = TextEditingController();
  final List<String> _photos = [];
  int? _selectedShopId;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _vehicleNameCtrl.dispose();
    _deptNameCtrl.dispose();
    _faultDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1920);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await xfile.readAsBytes();
      final resp = await HttpClient().uploadBytes('/upload/single', bytes, xfile.name, 'file');
      if (resp.isSuccess && resp.data != null) {
        final url = (resp.data as Map<String, dynamic>)['url'] ?? '';
        if (url.isNotEmpty) setState(() => _photos.add(url));
      }
    } catch (_) {}
    setState(() => _uploading = false);
  }

  Future<void> _submit() async {
    final name = _vehicleNameCtrl.text.trim();
    final desc = _faultDescCtrl.text.trim();
    if (name.isEmpty) { _snack('请填写车辆名称'); return; }
    if (_selectedShopId == null) { _snack('请选择修理厂'); return; }
    if (desc.isEmpty) { _snack('请填写故障描述'); return; }
    setState(() => _submitting = true);
    try {
      final no = await ref.read(externalRepairActionsProvider.notifier).reportFault(
        vehicleName: name,
        faultDescription: desc,
        faultImages: _photos,
        departmentName: _deptNameCtrl.text.trim(),
        repairShopId: _selectedShopId,
      );
      if (mounted) {
        _snack('报修成功，单号：$no');
        context.pop();
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(externalShopsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('外部报修'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 车辆信息
          _section('车辆信息', [
            _field('归属部门', _deptNameCtrl, hint: '如：选矿一厂、采矿场...（方便签字结算）'),
            const SizedBox(height: 8),
            _field('车辆名称', _vehicleNameCtrl, hint: '如：洒水车、装载机、皮卡...'),
          ]),
          const SizedBox(height: 12),
          // 修理厂选择
          shopsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (shops) {
              if (shops.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _section('选择修理厂', [
                  _shopDropdown(shops),
                ]),
              );
            },
          ),
          // 故障描述
          _section('故障描述', [
            TextField(
              controller: _faultDescCtrl,
              maxLines: 4,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: '请详细描述故障情况...',
                hintStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
                filled: true, fillColor: AppColors.bg,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // 照片
          _section('现场照片', [
            Wrap(spacing: 6, runSpacing: 6, children: [
              ..._photos.map((p) => _photoPreview(p)),
              _addPhotoBtn(),
            ]),
          ]),
          const SizedBox(height: 24),
          // 提交
          SizedBox(
            width: double.infinity, height: 44,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              child: Text(_submitting ? '提交中...' : '提交报修', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _shopDropdown(List<Map<String, dynamic>> shops) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedShopId,
          isExpanded: true,
          hint: const Text('请选择修理厂', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          items: shops.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name'] as String, style: const TextStyle(color: AppColors.text, fontSize: 14)))).toList(),
          onChanged: (v) => setState(() => _selectedShopId = v),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
        filled: true, fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
      ),
    );
  }

  Widget _photoPreview(String path) {
    return Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(ApiConfig.fileUrl(path), width: 80, height: 80, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppColors.surface2, child: const Icon(Icons.broken_image, color: AppColors.text2)))),
      Positioned(top: 0, right: 0, child: GestureDetector(
        onTap: () => setState(() => _photos.remove(path)),
        child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4))), child: const Icon(Icons.close, size: 14, color: Colors.white)),
      )),
    ]);
  }

  Widget _addPhotoBtn() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_uploading ? Icons.hourglass_top : Icons.add_photo_alternate, color: AppColors.text2, size: 22),
          const SizedBox(height: 2),
          Text(_uploading ? '上传中' : '添加照片', style: const TextStyle(color: AppColors.text2, fontSize: 9)),
        ]),
      ),
    );
  }

}
