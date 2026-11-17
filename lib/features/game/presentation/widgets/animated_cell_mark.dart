import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/xo_engine.dart';
import 'neon_o_widget.dart';
import 'neon_x_widget.dart';

/// Animated mark entrance for placed X and O symbols (UX-DELIGHT-01).
/// Scales from 0.6 -> 1.05 -> 1.0 with fade in 160ms (AppMotion.cellEnter).
/// When MediaQuery.disableAnimations is active, scales are suppressed and only a fade ≤ 150ms is applied.
class AnimatedCellMark extends StatefulWidget {
  final Player player;
  final double size;
  final bool isWinning;
  final bool hasGlow;

  const AnimatedCellMark({
    super.key,
    required this.player,
    required this.size,
    required this.isWinning,
    required this.hasGlow,
  });

  @override
  State<AnimatedCellMark> createState() => _AnimatedCellMarkState();
}

class _AnimatedCellMarkState extends State<AnimatedCellMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.cellEnter, // 160ms
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final child = widget.player == Player.x
        ? NeonXWidget(
            size: widget.size,
            isWinning: widget.isWinning,
            hasGlow: widget.hasGlow,
          )
        : NeonOWidget(
            size: widget.size,
            isWinning: widget.isWinning,
            hasGlow: widget.hasGlow,
          );

    if (reduceMotion) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: child,
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: child,
      ),
    );
  }
}
