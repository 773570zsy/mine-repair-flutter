import 'package:flutter/material.dart';
import '../config/color_constants.dart';
import '../services/photo_saver.dart';

/// 全屏照片查看器 — 支持多图轮播 + 下载保存
///
/// 用法:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => PhotoViewer(images: allUrls, initialIndex: tappedIndex),
/// ));
/// ```
class PhotoViewer extends StatefulWidget {
  /// 照片 URL 列表
  final List<String> images;

  /// 初始展示的图片索引
  final int initialIndex;

  const PhotoViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  /// 便捷构造：单张照片（向后兼容）
  factory PhotoViewer.single(String imageUrl) {
    return PhotoViewer(images: [imageUrl], initialIndex: 0);
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pageCtrl;
  late int _currentIdx;

  @override
  void initState() {
    super.initState();
    _currentIdx = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageCtrl = PageController(initialPage: _currentIdx);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    try {
      final url = widget.images[_currentIdx];
      final path = await PhotoSaver.instance.savePhoto(url, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path != null ? '已保存到: $path' : '已打开图片'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _goPrev() {
    if (_currentIdx > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _goNext() {
    if (_currentIdx < widget.images.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.images.length > 1;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ---- 图片轮播 ----
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.images.length,
            onPageChanged: (idx) => setState(() => _currentIdx = idx),
            itemBuilder: (ctx, idx) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.images[idx],
                    fit: BoxFit.contain,
                    width: size.width,
                    height: size.height,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: AppColors.text2, size: 64),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                          color: AppColors.gold,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // ---- 顶部工具栏 ----
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(children: [
                // 计数器（多张时显示）
                if (multi)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIdx + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                const Spacer(),
                // 下载按钮
                _toolBtn(Icons.download, _downloadCurrent),
                const SizedBox(width: 8),
                // 关闭按钮
                _toolBtn(Icons.close, () => Navigator.pop(context)),
              ]),
            ),
          ),

          // ---- 左右箭头（多张时显示）----
          if (multi) ...[
            // 左箭头
            Positioned(
              left: 4,
              top: size.height * 0.3,
              bottom: size.height * 0.3,
              child: Center(
                child: _arrowBtn(
                  Icons.chevron_left,
                  _currentIdx > 0 ? _goPrev : null,
                ),
              ),
            ),
            // 右箭头
            Positioned(
              right: 4,
              top: size.height * 0.3,
              bottom: size.height * 0.3,
              child: Center(
                child: _arrowBtn(
                  Icons.chevron_right,
                  _currentIdx < widget.images.length - 1 ? _goNext : null,
                ),
              ),
            ),
          ],

          // ---- 底部提示 ----
          if (multi)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '← 左右滑动切换  ·  点击两侧翻页  ·  点击中间关闭',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
            ),

          // ---- 点击空白关闭 / 点击两侧翻页 ----
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final w = size.width;
                  final x = details.localPosition.dx;
                  if (multi && x < w * 0.2) {
                    _goPrev();
                  } else if (multi && x > w * 0.8) {
                    _goNext();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _arrowBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap != null ? 1.0 : 0.0,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Icon(icon, color: Colors.white70, size: 28),
        ),
      ),
    );
  }
}
