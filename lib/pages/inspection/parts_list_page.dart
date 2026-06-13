import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/part.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../utils/pinyin_util.dart';

import '../../config/color_constants.dart';

class PartsListPage extends ConsumerStatefulWidget {
  const PartsListPage({super.key});

  @override
  ConsumerState<PartsListPage> createState() => _PartsListPageState();
}

class _PartsListPageState extends ConsumerState<PartsListPage> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _pulseCtrl;

  /// null = 显示全部；非 null = 搜索过滤后的结果
  List<PartItem>? _filteredParts;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _searchCtrl.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _focusNode.removeListener(_onFocusChanged);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 获取当前全集（缓存数据）
  List<PartItem>? get _allParts {
    final async = ref.read(partsListProvider);
    return async.valueOrNull;
  }

  void _onSearchChanged() {
    final kw = _searchCtrl.text.trim();
    if (kw.isEmpty) {
      setState(() => _filteredParts = null);
      return;
    }
    final all = _allParts;
    if (all == null) return;
    setState(() {
      _filteredParts = all.where((p) {
        if (matchPinyin(p.partName, kw)) return true;
        if (p.partCode != null && matchPinyin(p.partCode!, kw)) return true;
        return false;
      }).toList();
    });
  }

  void _onFocusChanged() {
    // 获得焦点且有输入时确保显示建议
    if (_focusNode.hasFocus && _searchCtrl.text.trim().isNotEmpty) {
      _onSearchChanged();
    }
  }

  void _selectPart(PartItem p) {
    _searchCtrl.text = p.partName;
    _focusNode.unfocus();
    setState(() => _filteredParts = [p]);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _focusNode.unfocus();
    setState(() => _filteredParts = null);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final partsAsync = ref.watch(partsListProvider);
    final isAdmin = user?.isAdmin == true;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('配件库存'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0,
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.tune, size: 20, color: AppColors.gold),
              tooltip: '阈值设置',
              onPressed: () => _showThresholdDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 20, color: AppColors.gold),
              onPressed: () => _showAddDialog(context),
            ),
          ],
        ],
      ),
      body: Stack(children: [
        Column(children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(10), color: AppColors.surface,
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              style: const TextStyle(color: AppColors.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索（支持中文 / 拼音首字母 / 编码）...',
                hintStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 16, color: AppColors.text2), onPressed: _clearSearch)
                    : null,
                filled: true, fillColor: AppColors.bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(partsAsync),
          ),
        ]),
        // 自动联想下拉
        if (_focusNode.hasFocus && _searchCtrl.text.trim().isNotEmpty)
          _buildSuggestions(),
      ]),
    );
  }

  /// 联想建议下拉
  Widget _buildSuggestions() {
    final all = _allParts;
    if (all == null) return const SizedBox.shrink();

    final kw = _searchCtrl.text.trim().toLowerCase();
    final suggestions = all.where((p) {
      if (matchPinyin(p.partName, kw)) return true;
      if (p.partCode != null && p.partCode!.toLowerCase().contains(kw)) return true;
      return false;
    }).take(8).toList();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 10, right: 10, top: 56 + MediaQuery.of(context).padding.top + kToolbarHeight,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) {
              final p = suggestions[i];
              return InkWell(
                onTap: () => _selectPart(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.build_outlined, size: 14, color: AppColors.text2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: _highlightMatch(p.partName, kw),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.partCode != null && p.partCode!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(p.partCode!, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                    ],
                    const SizedBox(width: 8),
                    Text('${p.quantity}${p.unit ?? "个"}',
                      style: TextStyle(fontSize: 11, color: p.isLowStock ? AppColors.danger : AppColors.text2)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 高亮匹配文本
  TextSpan _highlightMatch(String text, String query) {
    if (query.isEmpty) return TextSpan(text: text, style: const TextStyle(color: AppColors.text, fontSize: 13));

    final lowerText = text.toLowerCase();
    final idx = lowerText.indexOf(query);
    if (idx < 0) {
      // 拼音匹配，不高亮
      return TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        children: [
          TextSpan(text: '  (${toPinyinInitials(text)})', style: const TextStyle(color: AppColors.text2, fontSize: 10)),
        ],
      );
    }

    return TextSpan(children: [
      if (idx > 0) TextSpan(text: text.substring(0, idx), style: const TextStyle(color: AppColors.text, fontSize: 13)),
      TextSpan(text: text.substring(idx, idx + query.length), style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
      if (idx + query.length < text.length)
        TextSpan(text: text.substring(idx + query.length), style: const TextStyle(color: AppColors.text, fontSize: 13)),
    ]);
  }

  Widget _buildBody(AsyncValue<List<PartItem>> partsAsync) {
    if (_filteredParts != null) {
      return _buildList(_filteredParts!);
    }
    return partsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
      data: (parts) => _buildList(parts),
    );
  }

  Widget _buildList(List<PartItem> parts) {
    if (parts.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.text2),
        SizedBox(height: 8),
        Text('暂无配件', style: TextStyle(color: AppColors.text2)),
      ]));
    }
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async { ref.invalidate(partsListProvider); _clearSearch(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: parts.length,
        itemBuilder: (ctx, i) => _buildPartRow(parts[i]),
      ),
    );
  }

  Widget _buildPartRow(PartItem p) {
    final user = ref.read(authProvider).user;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.isLowStock ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(children: [
        // 低于阈值：动态红色警示三角（名字前面）
        if (p.isLowStock)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final alpha = 0.4 + 0.6 * _pulseCtrl.value;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.warning_amber_rounded, color: AppColors.danger.withValues(alpha: alpha), size: 20),
              );
            },
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(p.partName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              if (p.partCode != null && p.partCode!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(p.partCode!, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              ],
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text(
                '库存：${p.quantity}/${p.threshold} ${p.unit ?? "个"}',
                style: TextStyle(fontSize: 12, color: p.isLowStock ? AppColors.danger : AppColors.text2, fontWeight: FontWeight.w500),
              ),
              if (p.unitPrice != null) ...[
                const SizedBox(width: 12),
                Text('单价：¥${p.unitPrice!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
              ],
              if (p.remark != null && p.remark!.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1, height: 14,
                  color: AppColors.border,
                ),
                Flexible(child: Text(p.remark!, style: const TextStyle(fontSize: 11, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ]),
        ),
        // 驾驶员可见领用按钮
        if (user?.isDriver == true && p.quantity > 0)
          GestureDetector(
            onTap: () => context.push('/inspection/parts/requisition/${p.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
              child: const Text('领用', style: TextStyle(fontSize: 12, color: AppColors.bg, fontWeight: FontWeight.w600)),
            ),
          ),
        // 管理员删除按钮
        if (user?.isAdmin == true)
          GestureDetector(
            onTap: () => _deletePart(p),
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            ),
          ),
      ]),
    );
  }

  Future<void> _deletePart(PartItem p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认删除', style: TextStyle(color: AppColors.text)),
        content: Text('确定要删除配件"${p.partName}"吗？此操作不可撤销。', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(inspectionActionsProvider.notifier).deletePart(p.id);
      ref.invalidate(partsListProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配件已删除'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  /// 阈值设置弹窗
  void _showThresholdDialog(BuildContext ctx) {
    final partsAsync = ref.read(partsListProvider);
    partsAsync.whenData((parts) {
      showDialog(
        context: ctx,
        builder: (_) => _ThresholdDialog(parts: parts),
      ).then((_) => ref.invalidate(partsListProvider));
    });
  }

  void _showAddDialog(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final unitCtrl = TextEditingController(text: '个');
    final priceCtrl = TextEditingController(text: '0');
    final remarkCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('添加配件', style: TextStyle(color: AppColors.text)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dlgField('名称 *', nameCtrl, autofocus: true),
          _dlgField('编码', codeCtrl),
          _dlgField('数量', qtyCtrl, keyboardType: TextInputType.number),
          _dlgField('单位', unitCtrl),
          _dlgField('单价', priceCtrl, keyboardType: TextInputType.number),
          _dlgField('备注', remarkCtrl),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(inspectionActionsProvider.notifier).addPart(
                  partName: name, partCode: codeCtrl.text.trim(),
                  quantity: int.tryParse(qtyCtrl.text) ?? 0,
                  unit: unitCtrl.text.trim(), unitPrice: double.tryParse(priceCtrl.text) ?? 0,
                  remark: remarkCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(partsListProvider);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Widget _dlgField(String label, TextEditingController ctrl, {bool autofocus = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl, autofocus: autofocus, keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
    );
  }
}

/// 阈值设置弹窗内容
class _ThresholdDialog extends ConsumerStatefulWidget {
  final List<PartItem> parts;
  const _ThresholdDialog({required this.parts});

  @override
  ConsumerState<_ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends ConsumerState<_ThresholdDialog> {
  late Map<int, TextEditingController> _controllers;
  late Map<int, int> _dirty;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _dirty = {};
    for (final p in widget.parts) {
      _controllers[p.id] = TextEditingController(text: p.threshold.toString());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save(int id) async {
    final val = int.tryParse(_controllers[id]!.text.trim()) ?? 5;
    try {
      await ref.read(inspectionActionsProvider.notifier).updateThreshold(id, val.clamp(1, 999999));
      ref.invalidate(partsListProvider);
      if (mounted) setState(() => _dirty[id] = val);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(children: [
        Icon(Icons.tune, size: 18, color: AppColors.gold),
        SizedBox(width: 8),
        Text('库存阈值设置', style: TextStyle(color: AppColors.text, fontSize: 16)),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('低于阈值的配件将在列表中显示红色警示', style: TextStyle(color: AppColors.text2, fontSize: 12)),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.parts.length,
              itemBuilder: (_, i) {
                final p = widget.parts[i];
                final ctrl = _controllers[p.id]!;
                final saved = _dirty[p.id] ?? p.threshold;
                final isLow = p.quantity < saved;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isLow ? AppColors.danger.withValues(alpha: 0.25) : AppColors.border),
                  ),
                  child: Row(children: [
                    Expanded(
                      flex: 3,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.partName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('库存 ${p.quantity}${p.unit ?? "个"}', style: TextStyle(fontSize: 11, color: isLow ? AppColors.danger : AppColors.text2)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.text, fontSize: 13),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          filled: true, fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.gold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 40,
                      child: ElevatedButton(
                        onPressed: () => _save(p.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold, foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('保存', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭', style: TextStyle(color: AppColors.text2))),
      ],
    );
  }
}
