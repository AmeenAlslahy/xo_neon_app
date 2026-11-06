import 'package:flutter/material.dart';
import '../../app/theme/neon_colors.dart';

/// Glowing neon action button with reactive tap animation and accessibility support.
class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool isSecondary;
  final bool isSolid;
  final Color? customTextColor;
  final bool isDisabled;
  final EdgeInsetsGeometry? padding;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = NeonColors.cyanX,
    this.icon,
    this.isSecondary = false,
    this.isSolid = false,
    this.customTextColor,
    this.isDisabled = false,
    this.padding,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final effectiveColor = widget.isDisabled ? NeonColors.textMuted : widget.color;
    final effectivePadding = widget.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    final Color textAndIconColor;
    if (widget.isDisabled) {
      textAndIconColor = NeonColors.textMuted;
    } else if (widget.customTextColor != null) {
      textAndIconColor = widget.customTextColor!;
    } else if (widget.isSolid) {
      // Automatic high contrast calculation
      textAndIconColor = effectiveColor.computeLuminance() > 0.45
          ? const Color(0xFF070514)
          : Colors.white;
    } else {
      textAndIconColor = effectiveColor;
    }

    final Color backgroundColor;
    if (widget.isSolid) {
      backgroundColor = effectiveColor;
    } else if (widget.isSecondary) {
      backgroundColor = NeonColors.surfaceGlass;
    } else {
      backgroundColor = effectiveColor.withValues(alpha: 0.15);
    }

    return Semantics(
      button: true,
      enabled: !widget.isDisabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: widget.isDisabled
            ? null
            : (_) {
                if (!reduceMotion) setState(() => _isPressed = true);
              },
        onTapUp: widget.isDisabled
            ? null
            : (_) {
                if (!reduceMotion) setState(() => _isPressed = false);
              },
        onTapCancel: () {
          if (!reduceMotion && mounted) setState(() => _isPressed = false);
        },
        onTap: widget.isDisabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed && !reduceMotion ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: effectivePadding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSolid ? Colors.transparent : effectiveColor,
                width: widget.isSecondary ? 1.2 : 1.8,
              ),
              boxShadow: widget.isDisabled || widget.isSecondary
                  ? null
                  : NeonColors.glow(color: effectiveColor, blur: widget.isSolid ? 14 : 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: textAndIconColor, size: 18),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textAndIconColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
