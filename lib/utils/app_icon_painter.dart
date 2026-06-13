import 'dart:math';
import 'package:flutter/material.dart';

/// 总调度室综合管理系统 APP 图标
/// 紫金矿业旗下 — 写实风格矿山井架 + 调度台
class AppIconPainter extends CustomPainter {
  const AppIconPainter();

  // 配色
  static const _skyTop = Color(0xFF1A2A4A);       // 夜空顶部
  static const _skyBottom = Color(0xFF2D1F3D);     // 夜空底部（紫调）
  static const _gold = Color(0xFFD4A843);           // 结构金色
  static const _goldDark = Color(0xFFB8912E);
  static const _goldLight = Color(0xFFEBCA7A);
  static const _steel = Color(0xFF8899AA);
  static const _steelDark = Color(0xFF556677);
  static const _light = Color(0xFFEEDDAA);           // 灯光暖色
  static const _windowGlow = Color(0x88E8C860);      // 窗户光晕
  static const _green = Color(0xFF3DA87A);           // 调度屏
  static const _greenDim = Color(0xFF2A7A55);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── 1. 夜空渐变背景（圆角矩形） ──
    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.18),
    );
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_skyTop, _skyBottom],
    );
    canvas.drawRRect(
      bgRRect,
      Paint()..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── 2. 远景山脊线（剪影） ──
    _drawDistantRidge(canvas, cx, cy, w, h);

    // ── 3. 矿井架主体 ──
    _drawHeadframe(canvas, cx, cy, w, h);

    // ── 4. 底部建筑（调度室） ──
    _drawDispatchBuilding(canvas, cx, cy, w, h);

    // ── 5. 灯光/信号效果 ──
    _drawSignalLights(canvas, cx, cy, w, h);
  }

  // ── 远景山脊 ──
  void _drawDistantRidge(Canvas c, double cx, double cy, double w, double h) {
    final baseY = cy + h * 0.12;
    final path = Path();
    path.moveTo(0, baseY + h * 0.08);
    path.quadraticBezierTo(w * 0.15, baseY - h * 0.05, w * 0.28, baseY);
    path.quadraticBezierTo(w * 0.42, baseY + h * 0.04, w * 0.55, baseY - h * 0.03);
    path.quadraticBezierTo(w * 0.70, baseY + h * 0.06, w, baseY + h * 0.02);
    path.lineTo(w, baseY + h * 0.1);
    path.lineTo(0, baseY + h * 0.1);
    path.close();
    c.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2A3050).withValues(alpha: 0.6),
            const Color(0xFF1A1D2E).withValues(alpha: 0.3),
          ],
        ).createShader(Rect.fromLTWH(0, baseY - h * 0.06, w, h * 0.16)),
    );
  }

  // ── 矿井架（钢架结构） ──
  void _drawHeadframe(Canvas c, double cx, double cy, double w, double h) {
    final scale = w * 0.50; // 井架半宽
    final topY = cy - h * 0.32;      // 天轮位置
    final baseY = cy + h * 0.06;     // 底座位置
    final midY = (topY + baseY) / 2;
    final baseW = scale * 0.7;

    // -- 主塔柱（左右两根，带厚度感） --
    _drawSteelBeam(c, cx - baseW, baseY, cx - scale * 0.15, topY, w * 0.018, _gold);
    _drawSteelBeam(c, cx + baseW, baseY, cx + scale * 0.15, topY, w * 0.018, _gold);

    // -- 后斜撑（稍暗，体现立体） --
    _drawSteelBeam(c, cx - baseW * 0.5, baseY, cx - scale * 0.1, midY, w * 0.012, _goldDark);
    _drawSteelBeam(c, cx + baseW * 0.5, baseY, cx + scale * 0.1, midY, w * 0.012, _goldDark);

    // -- 横梁（多层） --
    for (int i = 1; i <= 4; i++) {
      final y = topY + (baseY - topY) * (i / 5.0);
      final leftX = cx - baseW + (cx - scale * 0.1 - (cx - baseW)) * (i / 5.0);
      final rightX = cx + baseW - (cx + baseW - (cx + scale * 0.1)) * (i / 5.0);
      _drawSteelBeamH(c, leftX, rightX, y, w * 0.008, _goldDark);
    }

    // -- X 型交叉撑 --
    for (int i = 0; i < 2; i++) {
      final y1 = topY + (baseY - topY) * ((i * 2 + 1) / 5.0);
      final y2 = topY + (baseY - topY) * ((i * 2 + 2) / 5.0);
      final l1 = cx - baseW + (cx - scale * 0.1 - (cx - baseW)) * ((i * 2 + 1) / 5.0);
      final r1 = cx + baseW - (cx + baseW - (cx + scale * 0.1)) * ((i * 2 + 1) / 5.0);
      final l2 = cx - baseW + (cx - scale * 0.1 - (cx - baseW)) * ((i * 2 + 2) / 5.0);
      final r2 = cx + baseW - (cx + baseW - (cx + scale * 0.1)) * ((i * 2 + 2) / 5.0);
      c.drawLine(Offset(l1, y1), Offset(r1, y2),
          Paint()..color = _steelDark..strokeWidth = w * 0.004);
      c.drawLine(Offset(r1, y1), Offset(l1, y2),
          Paint()..color = _steelDark..strokeWidth = w * 0.004);
    }

    // -- 天轮（顶部大滑轮） --
    _drawHeadframeWheel(c, cx, topY, w * 0.09);
  }

  void _drawSteelBeam(Canvas c, double x1, double y1, double x2, double y2, double thick, Color color) {
    // 主线条
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    // 高光线（模拟立体）
    final hlPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = thick * 0.35
      ..strokeCap = StrokeCap.round;
    final dx = (x2 - x1) * 0.0;
    final dy = (y2 - y1) * 0.0;
    c.drawLine(
      Offset(x1 + thick * 0.25, y1),
      Offset(x2 + thick * 0.25, y2),
      hlPaint,
    );
  }

  void _drawSteelBeamH(Canvas c, double x1, double x2, double y, double thick, Color color) {
    c.drawLine(Offset(x1, y), Offset(x2, y),
        Paint()..color = color..strokeWidth = thick..strokeCap = StrokeCap.round);
  }

  /// 天轮（绞轮 + 辐条）
  void _drawHeadframeWheel(Canvas c, double cx, double topY, double r) {
    // 轮圈
    c.drawCircle(Offset(cx, topY), r,
        Paint()..color = _goldDark..style = PaintingStyle.stroke..strokeWidth = r * 0.18);
    c.drawCircle(Offset(cx, topY), r * 0.85,
        Paint()..color = _gold..style = PaintingStyle.stroke..strokeWidth = r * 0.06);

    // 轮毂
    c.drawCircle(Offset(cx, topY), r * 0.22,
        Paint()..color = _goldLight);
    c.drawCircle(Offset(cx, topY), r * 0.1,
        Paint()..color = _goldDark);

    // 辐条
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      c.drawLine(
        Offset(cx + r * 0.22 * cos(angle), topY + r * 0.22 * sin(angle)),
        Offset(cx + r * 0.78 * cos(angle), topY + r * 0.78 * sin(angle)),
        Paint()..color = _gold..strokeWidth = r * 0.06,
      );
    }

    // 钢缆（从天轮下垂）
    c.drawLine(Offset(cx - r * 0.5, topY), Offset(cx - r * 0.5, topY + r * 1.2),
        Paint()..color = _steel..strokeWidth = r * 0.08);
    c.drawLine(Offset(cx + r * 0.5, topY), Offset(cx + r * 0.5, topY + r * 1.2),
        Paint()..color = _steel..strokeWidth = r * 0.08);
  }

  // ── 底部调度室建筑 ──
  void _drawDispatchBuilding(Canvas c, double cx, double cy, double w, double h) {
    final bldgY = cy + h * 0.06;
    final bldgH = h * 0.2;
    final bldgW = w * 0.44;

    // 主楼体
    final bldgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, bldgY + bldgH / 2), width: bldgW, height: bldgH),
      Radius.circular(w * 0.015),
    );
    c.drawRRect(bldgRect, Paint()..color = const Color(0xFF2A2D3A));

    // 建筑边线
    c.drawRRect(bldgRect,
        Paint()..color = _steelDark.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = w * 0.004);

    // 屋顶（略宽出挑）
    final roofPath = Path();
    roofPath.moveTo(cx - bldgW / 2 - w * 0.015, bldgY + w * 0.015);
    roofPath.lineTo(cx - bldgW / 2 - w * 0.015, bldgY);
    roofPath.lineTo(cx + bldgW / 2 + w * 0.015, bldgY);
    roofPath.lineTo(cx + bldgW / 2 + w * 0.015, bldgY + w * 0.015);
    roofPath.close();
    c.drawPath(roofPath, Paint()..color = _steelDark);

    // 调度屏幕窗口（发光）
    for (int i = -1; i <= 1; i++) {
      final wx = cx + i * w * 0.09;
      final wy = bldgY + bldgH * 0.35;
      final ww = w * 0.065;
      final wh = bldgH * 0.4;
      final winRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(wx, wy), width: ww, height: wh),
        Radius.circular(w * 0.006),
      );
      // 屏幕发光
      c.drawRRect(winRect, Paint()..color = _green.withValues(alpha: 0.3));
      // 屏幕内容线
      for (int j = 0; j < 3; j++) {
        final ly = wy - wh * 0.3 + j * wh * 0.25;
        c.drawLine(
          Offset(wx - ww * 0.4, ly),
          Offset(wx + ww * (0.2 + (j % 2) * 0.2), ly),
          Paint()..color = _greenDim.withValues(alpha: 0.8)..strokeWidth = w * 0.003..strokeCap = StrokeCap.round,
        );
      }
      // 屏幕边框
      c.drawRRect(winRect,
          Paint()..color = _steel.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = w * 0.003);
    }

    // 小窗户（暖光）
    for (int i = -2; i <= 2; i += 2) {
      final wx = cx + i * w * 0.065;
      final wy = bldgY + bldgH * 0.65;
      final winSize = w * 0.025;
      final winRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(wx, wy), width: winSize, height: winSize),
        Radius.circular(w * 0.004),
      );
      c.drawRRect(winRect, Paint()..color = _windowGlow);
      c.drawRRect(winRect,
          Paint()..color = _light.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = w * 0.002);
    }
  }

  // ── 信号灯（塔顶 + 建筑顶） ──
  void _drawSignalLights(Canvas c, double cx, double cy, double w, double h) {
    final topY = cy - h * 0.32;
    final r = w * 0.09;

    // 塔顶航空障碍灯（红色闪烁模拟）
    c.drawCircle(Offset(cx, topY - r * 0.3), w * 0.008, Paint()..color = const Color(0xFFFF4444));
    // 光晕
    c.drawCircle(Offset(cx, topY - r * 0.3), w * 0.016,
        Paint()..color = const Color(0x44FF4444));

    // 建筑顶部信号灯（绿色常亮）
    final bldgY = cy + h * 0.06;
    c.drawCircle(Offset(cx - w * 0.1, bldgY + w * 0.005), w * 0.005,
        Paint()..color = _green);
    c.drawCircle(Offset(cx + w * 0.1, bldgY + w * 0.005), w * 0.005,
        Paint()..color = _green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Widget ──

class AppIconWidget extends StatelessWidget {
  final double size;
  const AppIconWidget({super.key, this.size = 256});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const AppIconPainter()),
    );
  }
}

class AppIconExport extends StatelessWidget {
  final double size;
  final GlobalKey repaintKey;
  const AppIconExport({super.key, this.size = 1024, required this.repaintKey});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: const AppIconPainter()),
      ),
    );
  }
}
