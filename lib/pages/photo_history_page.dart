import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../config/color_constants.dart';
import '../config/api_config.dart';
import '../services/http_client.dart';
import '../widgets/photo_viewer.dart';

/// 照片历史查看器 — 按日期范围+分类浏览所有照片
class PhotoHistoryPage extends ConsumerStatefulWidget {
  const PhotoHistoryPage({super.key});

  @override
  ConsumerState<PhotoHistoryPage> createState() => _PhotoHistoryPageState();
}

class _PhotoHistoryPageState extends ConsumerState<PhotoHistoryPage> {
  final List<PhotoItem> _photos = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  int _requestId = 0;

  String _selectedCategory = '';
  DateTimeRange? _dateRange;

  static const int _pageSize = 50;

  static const _categories = [
    ('全部', Icons.photo_library, ''),
    ('维修', Icons.build, 'repair'),
    ('整改通报', Icons.warning_amber, 'hazard'),
    ('点检', Icons.fact_check, 'inspection'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
  }

  Future<void> _fetchPhotos({bool refresh = false}) async {
    if (refresh) { _page = 1; _hasMore = true; }
    if (!refresh && _loadingMore) return;

    final reqId = ++_requestId;
    setState(() {
      if (refresh) { _loading = true; _error = null; } else { _loadingMore = true; }
    });

    try {
      final params = <String, dynamic>{
        'page': refresh ? 1 : _page,
        'limit': _pageSize,
      };
      if (_dateRange != null) {
        final fmt = DateFormat('yyyy-MM-dd');
        params['start_date'] = fmt.format(_dateRange!.start);
        params['end_date'] = fmt.format(_dateRange!.end);
      }
      if (_selectedCategory.isNotEmpty) params['category'] = _selectedCategory;

      final resp = await HttpClient().get('/photos/history', queryParams: params);
      if (reqId != _requestId || !mounted) return;
      if (!resp.isSuccess || resp.data == null) throw Exception(resp.msg ?? '加载失败');

      final data = resp.data as Map<String, dynamic>;
      final items = (data['items'] as List?)?.map((e) => PhotoItem.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      if (reqId != _requestId || !mounted) return;

      setState(() {
        if (refresh) _photos.clear();
        _photos.addAll(items);
        _page = (data['page'] as int) + 1;
        _hasMore = items.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (reqId != _requestId || !mounted) return;
      setState(() { _loading = false; _loadingMore = false; _error = e.toString(); });
    }
  }

  void _onCategoryChanged(String cat) {
    if (cat == _selectedCategory) return;
    _selectedCategory = cat;
    _fetchPhotos(refresh: true);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: AppColors.bg,
            surface: AppColors.surface,
            onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _dateRange) {
      setState(() { _dateRange = picked; _activeYear = null; });
      _fetchPhotos(refresh: true);
    }
  }

  void _openViewer(int index) {
    final urls = _photos.map((p) => ApiConfig.fileUrl(p.url)).toList();
    Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewer(images: urls, initialIndex: index)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('照片历史'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildYearSelector(),
          _buildDateFilter(),
          _buildCategorySelector(),
          const Divider(color: AppColors.border, height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ---- 年份快捷选择 ----
  List<int> get _years { final y = DateTime.now().year; return List.generate(6, (i) => y - i); }

  int? _activeYear; // 当前选中年份（用于高亮）

  Widget _buildYearSelector() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 14, color: AppColors.gold),
          const SizedBox(width: 8),
          const Text('年份：', style: TextStyle(color: AppColors.text2, fontSize: 12)),
          ..._years.map((y) {
            final selected = _activeYear == y;
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: _chip('$y', selected: selected, onTap: () {
                setState(() {
                  if (_activeYear == y) {
                    _activeYear = null;
                    _dateRange = null;
                  } else {
                    _activeYear = y;
                    _dateRange = DateTimeRange(
                      start: DateTime(y, 1, 1),
                      end: DateTime(y, 12, 31),
                    );
                  }
                });
                _fetchPhotos(refresh: true);
              }),
            );
          }),
        ],
      ),
    );
  }

  // ---- 日期范围精筛 ----
  Widget _buildDateFilter() {
    final fmt = DateFormat('yyyy-MM-dd');
    final label = _dateRange != null
        ? '${fmt.format(_dateRange!.start)}  ~  ${fmt.format(_dateRange!.end)}'
        : '点击选择日期范围（可选）';
    final active = _dateRange != null;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.gold.withValues(alpha: 0.1) : AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: active ? AppColors.gold : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 16, color: active ? AppColors.gold : AppColors.text2),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12, color: active ? AppColors.gold : AppColors.text2)),
                  if (active) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() => _dateRange = null);
                        _fetchPhotos(refresh: true);
                      },
                      child: const Icon(Icons.close, size: 14, color: AppColors.text2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 分类 ----
  Widget _buildCategorySelector() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          ..._categories.map((c) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _chip(c.$1, selected: c.$3 == _selectedCategory, onTap: () => _onCategoryChanged(c.$3), hasIcon: true, icon: c.$2),
          )),
        ],
      ),
    );
  }

  Widget _chip(String label, {required bool selected, required VoidCallback onTap, bool hasIcon = false, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.gold : AppColors.border, width: selected ? 0 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIcon && icon != null) ...[
              Icon(icon, size: 14, color: selected ? AppColors.bg : AppColors.text2),
              const SizedBox(width: 2),
            ],
            Text(label, style: TextStyle(
              color: selected ? AppColors.bg : AppColors.text2,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }

  // ---- 照片网格 ----
  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    if (_error != null && _photos.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: AppColors.text2),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: AppColors.text2)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _fetchPhotos(refresh: true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
          child: const Text('重试'),
        ),
      ]));
    }
    if (_photos.isEmpty) {
      final catLabel = _categories.firstWhere((c) => c.$3 == _selectedCategory, orElse: () => _categories[0]).$1;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.photo_library_outlined, size: 48, color: AppColors.text2),
        const SizedBox(height: 12),
        Text('暂无$catLabel照片', style: const TextStyle(color: AppColors.text2, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('试试切换筛选条件', style: TextStyle(color: AppColors.text2, fontSize: 12)),
      ]));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          if (_hasMore && !_loadingMore) _fetchPhotos();
        }
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => _fetchPhotos(refresh: true),
        child: GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.72,
          ),
          itemCount: _photos.length + (_loadingMore ? 1 : 0),
          itemBuilder: (ctx, index) {
            if (index >= _photos.length) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
              ));
            }
            return _photoCard(_photos[index], index);
          },
        ),
      ),
    );
  }

  Widget _photoCard(PhotoItem item, int index) {
    final color = _sourceColor(item.sourceType);
    return GestureDetector(
      onTap: () => _openViewer(index),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 缩略图
            Expanded(
              child: CachedNetworkImage(
                imageUrl: ApiConfig.fileUrl(item.url),
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.surface2, child: const Center(child: Icon(Icons.image, color: AppColors.text2, size: 20))),
                errorWidget: (_, __, ___) => Container(color: AppColors.surface2, child: const Center(child: Icon(Icons.broken_image, color: AppColors.text2, size: 20))),
              ),
            ),
            // 底部信息：类型标签 + 工单号 + 时间
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 工单号
                  Text(item.orderNo, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  // 类型标签
                  Text(item.sourceLabel, style: const TextStyle(fontSize: 8, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
                  // 日期
                  Text(item.dateShort, style: const TextStyle(fontSize: 8, color: AppColors.text2), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _sourceColor(String type) {
    switch (type) {
      case 'repair': case 'external': return AppColors.danger;
      case 'inspection': return AppColors.success;
      case 'hazard_before': case 'hazard_after': return AppColors.warning;
      case 'assessment': return const Color(0xFFD4A017);
      case 'vehicle': return const Color(0xFF5B8DEF);
      case 'progress': case 'ext_progress': case 'quote_damage': case 'quote_new': return const Color(0xFF8B5CF6);
      case 'machinery': return const Color(0xFFE07B3C);
      default: return AppColors.text2;
    }
  }
}

/// 照片条目模型
class PhotoItem {
  final String url;
  final String sourceType;
  final String sourceLabel;
  final String recordDate;
  final int recordId;
  final String orderNo;   // 工单号
  final String category;  // 分类: repair/hazard/inspection/other

  PhotoItem({
    required this.url, required this.sourceType, required this.sourceLabel,
    required this.recordDate, required this.recordId,
    required this.orderNo, required this.category,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      url: (json['url'] as String?) ?? '',
      sourceType: (json['source_type'] as String?) ?? '',
      sourceLabel: (json['source_label'] as String?) ?? '',
      recordDate: (json['record_date'] as String?) ?? '',
      recordId: (json['record_id'] as int?) ?? 0,
      orderNo: (json['order_no'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
    );
  }

  String get dateShort {
    if (recordDate.length >= 16) return recordDate.substring(0, 16);
    if (recordDate.length >= 10) return recordDate.substring(0, 10);
    return recordDate;
  }
}
