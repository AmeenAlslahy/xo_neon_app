import 'package:flutter/material.dart';
import '../../app/theme/neon_colors.dart';
import '../services/haptics.dart';
import '../theme/app_tokens.dart';

/// Variants:
///   - Primary solid   : isSolid=true, color=cyanX  → filled cyan, dark text
///   - Secondary quiet : isSecondary=true            → outlined, dim background
///   - Danger          : isDanger=true               → filled dangerRed, white text
/// Primary buttons never ellipsize; secondary buttons may clip gracefully.
class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool isSecondary;
  final bool isSolid;
  final bool isDanger;
  final bool isOutlineDanger;
  final Color? customTextColor;
  final bool isDisabled;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = NeonColors.cyanX,
    this.icon,
    this.isSecondary = false,
    this.isSolid = false,
    this.isDanger = false,
    this.isOutlineDanger = false,
    this.customTextColor,
    this.isDisabled = false,
    this.padding,
    this.child,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final bool isDisabled = widget.isDisabled || widget.onPressed == null;

    // Danger overrides colour token
    final effectiveColor = (widget.isDanger || widget.isOutlineDanger)
        ? NeonColors.dangerRed
        : widget.color;

    final effectivePadding = widget.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    // ── Text / icon colour ────────────────────────────────────────────────
    final Color textAndIconColor;
    if (isDisabled) {
      textAndIconColor = NeonColors.textSecondary.withValues(alpha: 0.5);
    } else if (widget.customTextColor != null) {
      textAndIconColor = widget.customTextColor!;
    } else if (widget.isOutlineDanger) {
      textAndIconColor = NeonColors.dangerRed;
    } else if (widget.isDanger) {
      // High contrast dark text on red (#E94D45) gives 5.37:1 contrast (>4.5:1 WCAG AA)
      textAndIconColor = const Color(0xFF080611);
    } else if (widget.isSolid) {
      // Auto high-contrast for filled buttons
      textAndIconColor = effectiveColor.computeLuminance() > 0.35
          ? const Color(0xFF080611)
          : Colors.white;
    } else {
      textAndIconColor = effectiveColor;
    }

    // ── Background ────────────────────────────────────────────────────────
    final Color backgroundColor;
    if (isDisabled) {
      backgroundColor = NeonColors.surfaceElevated;
    } else if (widget.isOutlineDanger) {
      backgroundColor = NeonColors.surfaceElevated;
    } else if (widget.isDanger) {
      backgroundColor = NeonColors.dangerRed;
    } else if (widget.isSolid) {
      backgroundColor = effectiveColor;
    } else if (widget.isSecondary) {
      backgroundColor = NeonColors.surfaceElevated;
    } else {
      backgroundColor = effectiveColor.withValues(alpha: 0.14);
    }

    // ── Border ───────────────────────────────────────────────────────────
    final Color borderColor;
    if (isDisabled) {
      borderColor = NeonColors.borderSubtle;
    } else if (widget.isOutlineDanger) {
      borderColor = NeonColors.dangerRed;
    } else if (widget.isSolid || widget.isDanger) {
      borderColor = Colors.transparent;
    } else {
      borderColor = effectiveColor;
    }

    // ── Glow (only solid / danger / active primary) ───────────────────────
    final bool hasGlow =
        !isDisabled && !widget.isSecondary && !widget.isOutlineDanger && (widget.isSolid || widget.isDanger);

    return FocusableActionDetector(
      enabled: !isDisabled,
      onShowFocusHighlight: (show) => setState(() => _isFocused = show),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (!isDisabled) {
              if (widget.isSolid) {
                Haptics.primaryTap();
              }
              widget.onPressed?.call();
            }
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: !isDisabled,
        label: widget.label,
        child: GestureDetector(
          onTapDown: isDisabled
              ? null
              : (_) {
                  if (!reduceMotion) setState(() => _isPressed = true);
                },
          onTapUp: isDisabled
              ? null
              : (_) {
                  if (!reduceMotion) setState(() => _isPressed = false);
                },
          onTapCancel: () {
            if (!reduceMotion && mounted) setState(() => _isPressed = false);
          },
          onTap: isDisabled
              ? null
              : () {
                  if (widget.isSolid) {
                    Haptics.primaryTap();
                  }
                  widget.onPressed?.call();
                },
          child: AnimatedScale(
            scale: _isPressed && !reduceMotion ? 0.97 : 1.0,
            duration: AppMotion.press,
            curve: Curves.easeOut,
            child: Container(
              constraints: const BoxConstraints(minHeight: AppTokens.minTouchTargetSize),
              padding: effectivePadding,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isFocused ? Colors.white : borderColor,
                  width: _isFocused ? 2.0 : (widget.isSecondary || isDisabled ? 1.2 : 1.6),
                ),
                boxShadow: hasGlow
                    ? NeonColors.glow(color: effectiveColor, blur: 12)
                    : null,
              ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: textAndIconColor, size: 18),
                  const SizedBox(width: 6),
                ],
                if (widget.child != null)
                  widget.child!
                else if (widget.isSolid || widget.isDanger)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: textAndIconColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textAndIconColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
