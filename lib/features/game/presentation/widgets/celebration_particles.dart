import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';

/// Single Particle definition
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
  });
}

/// Lightweight, self-contained celebration particles overlay (UX-DELIGHT-01).
/// Maximum 36 particles radiating from line/origin center, fading in 1200ms (AppMotion.burst).
/// Wrapped in IgnorePointer and RepaintBoundary to eliminate board rebuilds and touch interception.
class CelebrationParticlesOverlay extends StatefulWidget {
  final Offset origin;
  final VoidCallback? onComplete;

  const CelebrationParticlesOverlay({
    super.key,
    required this.origin,
    this.onComplete,
  });

  @override
  State<CelebrationParticlesOverlay> createState() => _CelebrationParticlesOverlayState();
}

class _CelebrationParticlesOverlayState extends State<CelebrationParticlesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.burst, // 600ms approved token
    );

    // Generate up to 36 deterministic gold & cyan particles
    final random = math.Random(42);
    _particles = List.generate(32, (i) {
      final isGold = i.isEven;
      final angle = (i / 32) * 2 * math.pi + (random.nextDouble() - 0.5) * 0.4;
      final speed = 40.0 + random.nextDouble() * 90.0;
      final size = 3.5 + random.nextDouble() * 3.5;
      final color = isGold ? AppTokens.amberGold : AppTokens.cyan;
      final spin = (random.nextDouble() - 0.5) * 4.0;
      return _Particle(
        angle: angle,
        speed: speed,
        size: size,
        color: color,
        spin: spin,
      );
    });

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                progress: _controller.value,
                origin: widget.origin,
                particles: _particles,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Offset origin;
  final List<_Particle> particles;

  _ParticlePainter({
    required this.progress,
    required this.origin,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    // Fade out smoothly towards the end
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    // Ease out distance expansion
    final distanceProgress = Curves.easeOutCubic.transform(progress);

    for (final p in particles) {
      final distance = p.speed * distanceProgress;
      final x = origin.dx + math.cos(p.angle) * distance;
      final y = origin.dy + math.sin(p.angle) * distance;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * progress);

      // Draw diamond / star shape
      final path = Path();
      final half = p.size / 2;
      path.moveTo(0, -half * 1.3);
      path.lineTo(half, 0);
      path.lineTo(0, half * 1.3);
      path.lineTo(-half, 0);
      path.close();

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
