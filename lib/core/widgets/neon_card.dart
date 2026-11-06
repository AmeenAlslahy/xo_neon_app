import 'package:flutter/material.dart';
import '../../app/theme/neon_colors.dart';

/// Card container with subtle glassmorphic styling and optional neon border glow.
class NeonCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final bool hasGlow;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const NeonCard({
    super.key,
    required this.child,
    this.borderColor = NeonColors.borderSubtle,
    this.hasGlow = false,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: NeonColors.surfaceGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: hasGlow ? 1.6 : 1.0,
        ),
        boxShadow: hasGlow
            ? NeonColors.glow(color: borderColor, blur: 10, spread: 0.5)
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: borderColor.withValues(alpha: 0.2),
        highlightColor: Colors.transparent,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

