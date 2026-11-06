import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';

/// Renders a radiant, circular magenta neon 'O' with multi-layered glow.
class NeonOWidget extends StatelessWidget {
  final double size;
  final bool isWinning;

  const NeonOWidget({
    super.key,
    this.size = 48.0,
    this.isWinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'O',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _NeonOPainter(isWinning: isWinning),
        ),
      ),
    );
  }
}

class _NeonOPainter extends CustomPainter {
  final bool isWinning;

  _NeonOPainter({required this.isWinning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.72;
    final strokeWidth = size.width * 0.12;

    // 1. Wide outer neon glow
    final glowPaint = Paint()
      ..color = (isWinning ? NeonColors.amberGold : NeonColors.orangeO).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, radius, glowPaint);

    // 2. Focused vibrant stroke
    final vibrantPaint = Paint()
      ..color = isWinning ? NeonColors.amberGold : NeonColors.orangeO
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, vibrantPaint);

    // 3. Bright white neon core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.35;

    canvas.drawCircle(center, radius, corePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonOPainter oldDelegate) =>
      oldDelegate.isWinning != isWinning;
}

