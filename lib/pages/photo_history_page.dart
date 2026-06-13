import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/color_constants.dart';
import '../config/api_config.dart';
import '../services/http_client.dart';
import '../widgets/photo_viewer.dart';

/// 照片历史查看器 — 按年月浏览所有系统照片，支持5年历史追溯
///
/// 功能：
/// - 年份选择（当前年往前5年）
/// - 月份筛选（全部 / 1-12月）
/// - 照片瀑布流网格 + 来源标签 + 日期
/// - 点击进入全屏查看器
/// - 下拉刷新 + 上拉加载更多
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
  int _requestId = 0; // 防竞态：切换筛选条件时忽略旧请求

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0; // 0 = 全部月份

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
  }

  List<int> get _years {
    final now = DateTime.now().year;
    return List.generate(6, (i) => now - i); // 当前年往前5年
  }

  static const _monthLabels = [
    '全部', '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月',
  ];

  Future<void> _fetchPhotos({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!refresh && _loadingMore) return;

    final reqId = ++_requestId; // 防竞态

    setState(() {
      if (refresh) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final params = <String, dynamic>{
        'year': _selectedYear.toString(),
        'page': refresh ? 1 : _page,
        'limit': _pageSize,
      };
      if (_selectedMonth > 0) {
        params['month'] = _selectedMonth.toString();
      }

      final resp = await HttpClient().get('/photos/history', queryParams: params);
      // 竞态保护：忽略过期响应
      if (reqId != _requestId || !mounted) return;

      if (!resp.isSuccess || resp.data == null) {
        throw Exception(resp.msg ?? '加载失败');
      }

      final data = resp.data as Map<String, dynamic>;
      final items = (data['items'] as List?)?.map((e) => PhotoItem.fromJson(e as Map<String, dynamic>)).toList() ?? [];

      if (reqId != _requestId || !mounted) return; // 二次竞态保护

      setState(() {
        if (refresh) {
          _photos.clear();
        }
        _photos.addAll(items);
        _page = (data['page'] as int) + 1;
        _hasMore = items.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (reqId != _requestId || !mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  void _onYearChanged(int year) {
    if (year == _selectedYear) return;
    _selectedYear = year;
    _fetchPhotos(refresh: true);
  }

  void _onMonthChanged(int? month) {
    if (month == null || month == _selectedMonth) return;
    _selectedMonth = month;
    _fetchPhotos(refresh: true);
  }

  void _openViewer(int index) {
    final urls = _photos.map((p) => ApiConfig.fileUrl(p.url)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoViewer(images: urls, initialIndex: index)),
    );
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
          // ---- 年份选择 ----
          _buildYearSelector(),
          // ---- 月份选择 ----
          _buildMonthSelector(),
          const Divider(color: AppColors.border, height: 1),
          // ---- 照片网格 ----
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          const Text('年份：', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          ..._years.map((y) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chip(
                  '$y',
                  selected: y == _selectedYear,
                  onTap: () => _onYearChanged(y),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.view_module, size: 14, color: AppColors.text2),
            const SizedBox(width: 6),
            ...List.generate(13, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _chip(
                  _monthLabels[i],
                  selected: i == _selectedMonth,
                  onTap: () => _onMonthChanged(i),
                  small: true,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {required bool selected, required VoidCallback onTap, bool small = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.gold : AppColors.border, width: selected ? 0 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.bg : AppColors.text2,
            fontSize: small ? 11 : 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null && _photos.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.text2),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _fetchPhotos(refresh: true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            child: const Text('重试'),
          ),
        ]),
      );
    }
    if (_photos.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined, size: 48, color: AppColors.text2),
          const SizedBox(height: 12),
          Text(
            _selectedMonth > 0
                ? '${_selectedYear}年${_selectedMonth}月暂无照片'
                : '${_selectedYear}年暂无照片',
            style: const TextStyle(color: AppColors.text2, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text('试试切换年份或月份', style: TextStyle(color: AppColors.text2, fontSize: 12)),
        ]),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
          if (_hasMore && !_loadingMore) {
            _fetchPhotos();
          }
        }
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => _fetchPhotos(refresh: true),
        child: GridView.builder(
          padding: const EdgeInsets.all(6),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.85,
          ),
          itemCount: _photos.length + (_loadingMore ? 1 : 0),
          itemBuilder: (ctx, index) {
            if (index >= _photos.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                ),
              );
            }
            return _photoCard(_photos[index], index);
          },
        ),
      ),
    );
  }

  Widget _photoCard(PhotoItem item, int index) {
    return GestureDetector(
      onTap: () => _openViewer(index),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
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
                placeholder: (_, __) => Container(color: AppColors.surface2, child: const Center(child: Icon(Icons.image, color: AppColors.text2, size: 32))),
                errorWidget: (_, __, ___) => Container(color: AppColors.surface2, child: const Center(child: Icon(Icons.broken_image, color: AppColors.text2, size: 32))),
              ),
            ),
            // 底部信息
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 来源标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _sourceColor(item.sourceType).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      item.sourceLabel,
                      style: TextStyle(fontSize: 9, color: _sourceColor(item.sourceType), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // 日期
                  Text(
                    item.dateShort,
                    style: const TextStyle(fontSize: 10, color: AppColors.text2),
                    maxLines: 1,
                  ),
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
      case 'repair':
      case 'external':
        return AppColors.danger;
      case 'inspection':
        return AppColors.success;
      case 'hazard_before':
      case 'hazard_after':
        return AppColors.warning;
      case 'assessment':
        return const Color(0xFFD4A017);
      case 'vehicle':
        return const Color(0xFF5B8DEF);
      case 'progress':
      case 'ext_progress':
      case 'quote_damage':
      case 'quote_new':
        return const Color(0xFF8B5CF6);
      case 'machinery':
        return const Color(0xFFE07B3C);
      default:
        return AppColors.text2;
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

  PhotoItem({
    required this.url,
    required this.sourceType,
    required this.sourceLabel,
    required this.recordDate,
    required this.recordId,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      url: (json['url'] as String?) ?? '',
      sourceType: (json['source_type'] as String?) ?? '',
      sourceLabel: (json['source_label'] as String?) ?? '',
      recordDate: (json['record_date'] as String?) ?? '',
      recordId: (json['record_id'] as int?) ?? 0,
    );
  }

  String get dateShort {
    if (recordDate.length >= 10) {
      return recordDate.substring(0, 10);
    }
    return recordDate;
  }
}
