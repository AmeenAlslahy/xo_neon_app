import 'package:flutter/material.dart';
import '../../app/theme/neon_colors.dart';

/// Card container with unified surface colour and optional neon border glow.
/// Background uses the proper solid surface token — not opacity-based glass.
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
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: hasGlow ? 1.5 : 1.0,
        ),
        boxShadow: hasGlow
            ? NeonColors.glow(color: borderColor, blur: 8, spread: 0)
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: borderColor.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
