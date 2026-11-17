import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import 'celebration_glyphs.dart';

enum CelebrationType {
  roundWon,      // جولة لك! (Trophy + Gold)
  roundLost,     // جولة للخصم (Text only, calm textSecondary)
  matchWon,      // مبروك! فزت (Crown + Gold)
  matchLost,     // فاز الخصم — كانت قريبة (Text only, calm textSecondary)
  draw,          // تعادل — مباراة متكافئة (Interlocking X/O + Calm Cyan)
}

/// Floating celebration banner presented transiently without blocking touch interaction (UX-DELIGHT-01).
/// Automatically dismisses at AppMotion.banner (1800ms) for rounds or 2000ms for match conclusions.
/// Uses IgnorePointer to ensure board cells and controls remain fully interactive.
class CelebrationBanner extends StatefulWidget {
  final CelebrationType type;
  final VoidCallback? onDismissed;

  const CelebrationBanner({
    super.key,
    required this.type,
    this.onDismissed,
  });

  @override
  State<CelebrationBanner> createState() => _CelebrationBannerState();
}

class _CelebrationBannerState extends State<CelebrationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final duration = (widget.type == CelebrationType.matchWon ||
            widget.type == CelebrationType.matchLost)
        ? const Duration(milliseconds: 2000)
        : AppMotion.banner; // 1800ms

    _controller = AnimationController(
      vsync: this,
      duration: duration,
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: AppMotion.enter)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: AppMotion.pop)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 80,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onDismissed?.call();
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final Color borderColor;
    final Color backgroundColor;
    final String title;
    final Widget? glyph;

    switch (widget.type) {
      case CelebrationType.roundWon:
        borderColor = AppTokens.amberGold;
        backgroundColor = AppTokens.surfaceElevated;
        title = isArabic ? 'جولة لك!' : 'Round Won!';
        glyph = const TrophyGlyphWidget(size: 32);
        break;
      case CelebrationType.roundLost:
        borderColor = AppTokens.borderSubtle;
        backgroundColor = AppTokens.surfaceElevated;
        title = isArabic ? 'جولة للخصم' : 'Opponent Won Round';
        glyph = null; // No glyph for loss
        break;
      case CelebrationType.matchWon:
        borderColor = AppTokens.amberGold;
        backgroundColor = AppTokens.surfaceElevated;
        title = isArabic ? 'مبروك! فزت' : 'Congratulations! You Won';
        glyph = const CrownGlyphWidget(size: 40);
        break;
      case CelebrationType.matchLost:
        borderColor = AppTokens.borderSubtle;
        backgroundColor = AppTokens.surfaceElevated;
        title = isArabic ? 'فاز الخصم — كانت قريبة' : 'Opponent Won — Close Match';
        glyph = null; // No glyph for loss
        break;
      case CelebrationType.draw:
        borderColor = AppTokens.cyan;
        backgroundColor = AppTokens.surfaceElevated;
        title = isArabic ? 'تعادل — مباراة متكافئة' : 'Draw — Evenly Matched';
        glyph = const DrawGlyphWidget(size: 30);
        break;
    }

    final content = Semantics(
      liveRegion: true,
      label: title,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.22),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (glyph != null) ...[
              glyph,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: (widget.type == CelebrationType.matchLost ||
                          widget.type == CelebrationType.roundLost)
                      ? AppTokens.textSecondary
                      : (widget.type == CelebrationType.draw
                          ? AppTokens.cyan
                          : AppTokens.amberGold),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Pass touch interactions through completely
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (reduceMotion) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: content,
            );
          }
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: content,
            ),
          );
        },
      ),
    );
  }
}
