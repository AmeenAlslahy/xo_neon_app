import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';

/// Renders a sharp, luminous cyber-cyan neon 'X' with multi-layered glow.
class NeonXWidget extends StatelessWidget {
  final double size;
  final bool isWinning;

  const NeonXWidget({
    super.key,
    this.size = 48.0,
    this.isWinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'X',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _NeonXPainter(isWinning: isWinning),
        ),
      ),
    );
  }
}

class _NeonXPainter extends CustomPainter {
  final bool isWinning;

  _NeonXPainter({required this.isWinning});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = size.width * 0.18;
    final strokeWidth = size.width * 0.12;

    final p1 = Offset(padding, padding);
    final p2 = Offset(size.width - padding, size.height - padding);
    final p3 = Offset(size.width - padding, padding);
    final p4 = Offset(padding, size.height - padding);

    // 1. Wide outer neon glow
    final glowPaint = Paint()
      ..color = (isWinning ? NeonColors.amberGold : NeonColors.cyanX).withValues(alpha: 0.35)
      ..strokeWidth = strokeWidth * 2.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(p1, p2, glowPaint);
    canvas.drawLine(p3, p4, glowPaint);

    // 2. Focused vibrant stroke
    final vibrantPaint = Paint()
      ..color = isWinning ? NeonColors.amberGold : NeonColors.cyanX
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(p1, p2, vibrantPaint);
    canvas.drawLine(p3, p4, vibrantPaint);

    // 3. Bright white neon core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = strokeWidth * 0.35
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(p1, p2, corePaint);
    canvas.drawLine(p3, p4, corePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonXPainter oldDelegate) =>
      oldDelegate.isWinning != isWinning;
}

