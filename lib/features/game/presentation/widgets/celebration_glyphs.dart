import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';

/// Vector Celebration Glyphs (UX-DELIGHT-01).
/// All celebration iconography is drawn via CustomPainter for crisp neon vector fidelity
/// across all Android and iOS device displays without system emoji variance or external assets.

/// 1. Trophy Glyph (كأس) — Round Win (Gold #F4BD3E + Sparks)
class TrophyGlyphWidget extends StatelessWidget {
  final double size;
  final bool showSparks;

  const TrophyGlyphWidget({
    super.key,
    this.size = 48.0,
    this.showSparks = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TrophyPainter(showSparks: showSparks),
      ),
    );
  }
}

class _TrophyPainter extends CustomPainter {
  final bool showSparks;

  _TrophyPainter({this.showSparks = true});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final goldPaint = Paint()
      ..color = AppTokens.amberGold
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppTokens.amberGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, w * 0.05)
      ..strokeCap = StrokeCap.round;

    final cyanSparkPaint = Paint()
      ..color = AppTokens.cyan
      ..style = PaintingStyle.fill;

    // Cup Body
    final cupPath = Path();
    cupPath.moveTo(w * 0.28, h * 0.25);
    cupPath.lineTo(w * 0.72, h * 0.25);
    cupPath.cubicTo(w * 0.72, h * 0.52, w * 0.62, h * 0.62, w * 0.50, h * 0.64);
    cupPath.cubicTo(w * 0.38, h * 0.62, w * 0.28, h * 0.52, w * 0.28, h * 0.25);
    cupPath.close();
    canvas.drawPath(cupPath, goldPaint);

    // Handles (Left and Right)
    final leftHandle = Path()
      ..moveTo(w * 0.28, h * 0.30)
      ..cubicTo(w * 0.12, h * 0.30, w * 0.12, h * 0.48, w * 0.30, h * 0.50);
    canvas.drawPath(leftHandle, strokePaint);

    final rightHandle = Path()
      ..moveTo(w * 0.72, h * 0.30)
      ..cubicTo(w * 0.88, h * 0.30, w * 0.88, h * 0.48, w * 0.70, h * 0.50);
    canvas.drawPath(rightHandle, strokePaint);

    // Stem / Pedestal
    final stem = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.71),
      width: w * 0.12,
      height: h * 0.14,
    );
    canvas.drawRect(stem, goldPaint);

    // Base Tier
    final baseRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.83),
        width: w * 0.46,
        height: h * 0.10,
      ),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(baseRRect, goldPaint);

    // 4 Sparks (Gold & Cyan)
    if (showSparks) {
      _drawSpark(canvas, Offset(w * 0.16, h * 0.16), w * 0.045, cyanSparkPaint);
      _drawSpark(canvas, Offset(w * 0.84, h * 0.16), w * 0.045, goldPaint);
      _drawSpark(canvas, Offset(w * 0.50, h * 0.10), w * 0.040, cyanSparkPaint);
      _drawSpark(canvas, Offset(w * 0.20, h * 0.68), w * 0.030, goldPaint);
    }
  }

  void _drawSpark(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter oldDelegate) =>
      oldDelegate.showSparks != showSparks;
}

/// 2. Crown Glyph (تاج) — Match Win (Gold #F4BD3E + Sparks)
class CrownGlyphWidget extends StatelessWidget {
  final double size;
  final bool showSparks;

  const CrownGlyphWidget({
    super.key,
    this.size = 56.0,
    this.showSparks = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrownPainter(showSparks: showSparks),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final bool showSparks;

  _CrownPainter({this.showSparks = true});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final goldPaint = Paint()
      ..color = AppTokens.amberGold
      ..style = PaintingStyle.fill;

    final cyanSparkPaint = Paint()
      ..color = AppTokens.cyan
      ..style = PaintingStyle.fill;

    // Crown Peaks Path (5 peaks with majestic center peak)
    final crownPath = Path();
    crownPath.moveTo(w * 0.16, h * 0.72);
    crownPath.lineTo(w * 0.14, h * 0.40); // Left peak
    crownPath.lineTo(w * 0.32, h * 0.52);
    crownPath.lineTo(w * 0.50, h * 0.28); // Center peak (tallest)
    crownPath.lineTo(w * 0.68, h * 0.52);
    crownPath.lineTo(w * 0.86, h * 0.40); // Right peak
    crownPath.lineTo(w * 0.84, h * 0.72);
    crownPath.close();
    canvas.drawPath(crownPath, goldPaint);

    // Crown Head Jewels (Spheres on peak tips)
    canvas.drawCircle(Offset(w * 0.14, h * 0.39), w * 0.038, goldPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.26), w * 0.048, goldPaint);
    canvas.drawCircle(Offset(w * 0.86, h * 0.39), w * 0.038, goldPaint);

    // Crown Base Band
    final bandRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.72, w * 0.72, h * 0.10),
      Radius.circular(w * 0.025),
    );
    canvas.drawRRect(bandRRect, goldPaint);

    // Band Jewels (Cyan & White points)
    final jewelCyan = Paint()..color = AppTokens.cyan;
    canvas.drawCircle(Offset(w * 0.30, h * 0.77), w * 0.022, jewelCyan);
    canvas.drawCircle(Offset(w * 0.50, h * 0.77), w * 0.026, jewelCyan);
    canvas.drawCircle(Offset(w * 0.70, h * 0.77), w * 0.022, jewelCyan);

    // 5 Sparks (Gold & Cyan)
    if (showSparks) {
      _drawSpark(canvas, Offset(w * 0.14, h * 0.22), w * 0.045, cyanSparkPaint);
      _drawSpark(canvas, Offset(w * 0.86, h * 0.22), w * 0.045, goldPaint);
      _drawSpark(canvas, Offset(w * 0.50, h * 0.12), w * 0.050, goldPaint);
      _drawSpark(canvas, Offset(w * 0.28, h * 0.22), w * 0.035, goldPaint);
      _drawSpark(canvas, Offset(w * 0.72, h * 0.22), w * 0.035, cyanSparkPaint);
    }
  }

  void _drawSpark(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.showSparks != showSparks;
}

/// 3. Interlocking X and O Glyph — Draw (Calm Cyan, #13D5E4)
class DrawGlyphWidget extends StatelessWidget {
  final double size;

  const DrawGlyphWidget({
    super.key,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _DrawInterlockingPainter(),
      ),
    );
  }
}

class _DrawInterlockingPainter extends CustomPainter {
  const _DrawInterlockingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = math.max(2.2, w * 0.08);

    final cyanPaint = Paint()
      ..color = AppTokens.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final mutedCyanPaint = Paint()
      ..color = AppTokens.cyan.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Interlocked X and O:
    // Draw left-leaning X branch
    canvas.drawLine(
      Offset(w * 0.20, h * 0.22),
      Offset(w * 0.58, h * 0.78),
      cyanPaint,
    );

    // Draw full O ring nestled in the intersection
    canvas.drawCircle(
      Offset(w * 0.55, h * 0.50),
      w * 0.25,
      mutedCyanPaint,
    );

    // Draw right-leaning X branch crossing through
    canvas.drawLine(
      Offset(w * 0.58, h * 0.22),
      Offset(w * 0.20, h * 0.78),
      cyanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DrawInterlockingPainter oldDelegate) => false;
}
