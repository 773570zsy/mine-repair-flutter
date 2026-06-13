import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../config/color_constants.dart';
import '../../providers/repair_provider.dart';
import '../../services/http_client.dart';

/// 修理厂提交报价 — 完全照搬3000版 repair.js showQuote + photos.js
class SubmitQuotePage extends ConsumerStatefulWidget {
  final int orderId;
  final bool isReQuote;

  const SubmitQuotePage({super.key, required this.orderId, this.isReQuote = false});

  @override
  ConsumerState<SubmitQuotePage> createState() => _SubmitQuotePageState();
}

class _SubmitQuotePageState extends ConsumerState<SubmitQuotePage> {
  final _partsCostCtrl = TextEditingController();
  final _laborCostCtrl = TextEditingController();
  final _hoursCostCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _picker = ImagePicker();

  final List<_PartRow> _parts = [];
  final List<String> _dmgPhotos = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _parts.add(_PartRow());
    if (widget.isReQuote) _loadPreviousQuote();
  }

  @override
  void dispose() {
    _partsCostCtrl.dispose();
    _laborCostCtrl.dispose();
    _hoursCostCtrl.dispose();
    _daysCtrl.dispose();
    _detailCtrl.dispose();
    for (final p in _parts) { p.dispose(); }
    super.dispose();
  }

  Future<void> _loadPreviousQuote() async {
    try {
      final detail = ref.read(orderDetailProvider(widget.orderId)).valueOrNull?.order;
      if (detail != null) {
        _partsCostCtrl.text = '${detail.partsCost ?? 0}';
        _laborCostCtrl.text = '${detail.laborCost ?? 0}';
        _hoursCostCtrl.text = '${detail.hoursCost ?? 0}';
        _daysCtrl.text = '${detail.estimatedDays ?? ''}';
        _detailCtrl.text = detail.quoteDetail ?? '';
        if (detail.partsList != null && detail.partsList!.isNotEmpty) {
          try {
            final decoded = jsonDecode(detail.partsList!) as List<dynamic>;
            _parts.clear();
            for (final item in decoded) {
              final map = item as Map<String, dynamic>;
              _parts.add(_PartRow(name: map['name'] ?? '', qty: '${map['qty'] ?? ''}', price: '${map['price'] ?? ''}'));
            }
          } catch (_) {}
        }
        setState(() {});
      }
    } catch (_) {}
  }

  // ---- 照片上传 ----
  Future<void> _pickCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      _uploadPhoto(bytes, xfile.name);
    }
  }

  Future<void> _pickGallery() async {
    final xfiles = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1920);
    for (final xf in xfiles) {
      final bytes = await xf.readAsBytes();
      _uploadPhoto(bytes, xf.name);
    }
  }

  Future<void> _uploadPhoto(Uint8List bytes, String filename) async {
    try {
      final resp = await HttpClient().uploadBytes('/upload/single', bytes, filename, 'file');
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map ? resp.data as Map : null;
        final url = data?['url']?.toString() ?? data?['path']?.toString() ?? '';
        if (url.isNotEmpty) setState(() => _dmgPhotos.add(url));
      }
    } catch (e) {
      if (mounted) _showMsg('上传照片失败: $e');
    }
  }

  // ---- 提交 ----
  Future<void> _submit() async {
    final total = _partsCost + _laborCost + _hoursCost;
    if (total <= 0) {
      _showMsg('请填写费用');
      return;
    }
    final partsList = _parts
        .where((p) => p.nameCtrl.text.trim().isNotEmpty)
        .map((p) => {'name': p.nameCtrl.text.trim(), 'qty': int.tryParse(p.qtyCtrl.text.trim()) ?? 0, 'price': double.tryParse(p.priceCtrl.text.trim()) ?? 0})
        .toList();

    setState(() => _loading = true);
    try {
      await ref.read(repairActionsProvider.notifier).submitQuote(
            orderId: widget.orderId,
            quoteAmount: total,
            partsCost: _partsCost,
            laborCost: _laborCost,
            hoursCost: _hoursCost,
            partsList: partsList,
            quoteDetail: _detailCtrl.text.trim(),
            estimatedDays: int.tryParse(_daysCtrl.text.trim()),
            damagePhotos: _dmgPhotos,
          );
      if (mounted) {
        _showMsg(widget.isReQuote ? '重新报价已提交' : '报价已提交');
        ref.invalidate(orderDetailProvider(widget.orderId));
        context.pop();
      }
    } catch (e) {
      _showMsg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.surface));
  }

  double get _partsCost => double.tryParse(_partsCostCtrl.text.trim()) ?? 0;
  double get _laborCost => double.tryParse(_laborCostCtrl.text.trim()) ?? 0;
  double get _hoursCost => double.tryParse(_hoursCostCtrl.text.trim()) ?? 0;
  double get _totalAmt => _partsCost + _laborCost + _hoursCost;

  static const _labelStyle = TextStyle(fontSize: 13, color: AppColors.text2, fontWeight: FontWeight.w500, letterSpacing: 0.5);
  static const _inputStyle = TextStyle(fontSize: 14, color: AppColors.text);
  static const _inputDeco = InputDecoration(
    filled: true, fillColor: AppColors.bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.gold)),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.isReQuote ? '重新报价' : '提交报价'),
        backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label('配件清单'),
          const SizedBox(height: 6),
          ..._parts.asMap().entries.map((e) => _partRow(e.key, e.value)),
          TextButton.icon(
            onPressed: () => setState(() => _parts.add(_PartRow())),
            icon: const Icon(Icons.add, size: 14, color: AppColors.gold),
            label: const Text('添加配件', style: TextStyle(fontSize: 12, color: AppColors.gold)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
          ),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: _field('配件总费用', _partsCostCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: _field('人工费', _laborCostCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _field('工时费', _hoursCostCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: _field('预计天数', _daysCtrl, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 14),

          _label('合计报价'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Text('¥${_totalAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.danger)),
          ),
          const SizedBox(height: 14),

          // 损坏配件照片
          _photoSection('损坏配件照片', _dmgPhotos),
          const SizedBox(height: 14),

          _label('报价说明'),
          const SizedBox(height: 6),
          TextField(
            controller: _detailCtrl, maxLines: 4, style: _inputStyle,
            decoration: const InputDecoration(
              hintText: '详细说明维修方案、配件清单等...', hintStyle: TextStyle(fontSize: 13, color: AppColors.text2),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.gold)),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                : Text(widget.isReQuote ? '重新报价' : '提交报价'),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: _labelStyle);

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboardType, ValueChanged<String>? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label), const SizedBox(height: 6),
      TextField(controller: ctrl, keyboardType: keyboardType, style: _inputStyle, onChanged: onChanged, decoration: _inputDeco),
    ]);
  }

  Widget _partRow(int index, _PartRow part) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(flex: 2, child: TextField(controller: part.nameCtrl, style: _inputStyle, decoration: const InputDecoration(hintText: '配件名称', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()))),
        const SizedBox(width: 4),
        Expanded(child: TextField(controller: part.qtyCtrl, keyboardType: TextInputType.number, style: _inputStyle, decoration: const InputDecoration(hintText: '数量', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), border: OutlineInputBorder()))),
        const SizedBox(width: 4),
        Expanded(child: TextField(controller: part.priceCtrl, keyboardType: TextInputType.number, style: _inputStyle, decoration: const InputDecoration(hintText: '单价', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), border: OutlineInputBorder()))),
      ]),
    );
  }

  Widget _photoSection(String label, List<String> photos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...photos.asMap().entries.map((e) => Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                ApiConfig.fileUrl(e.value),
                width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppColors.border, child: const Icon(Icons.broken_image, color: AppColors.text2)),
              ),
            ),
            Positioned(top: 0, right: 0,
              child: GestureDetector(
                onTap: () => setState(() => photos.removeAt(e.key)),
                child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(2)), child: const Icon(Icons.close, size: 14, color: Colors.white)),
              ),
            ),
          ])),
          _photoBtn(Icons.camera_alt, '拍照', _pickCamera),
          _photoBtn(Icons.photo_library, '相册', _pickGallery),
        ]),
      ]),
    );
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.text2, fontSize: 10)),
        ]),
      ),
    );
  }
}

class _PartRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  _PartRow({String name = '', String qty = '', String price = ''}) {
    nameCtrl.text = name;
    qtyCtrl.text = qty;
    priceCtrl.text = price;
  }
  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
