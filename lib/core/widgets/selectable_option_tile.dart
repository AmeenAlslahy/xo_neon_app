import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Unified selectable tile across GameSetupScreen and CreateRoomScreen.
/// Implements the strict UX-CLARITY-02 selection rule:
/// Cyan 1.5dp border + 10% Cyan fill + Cyan checkmark.
class SelectableOptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? leading;
  final Widget? badge;
  final EdgeInsetsGeometry padding;
  final double? minHeight;

  const SelectableOptionTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.badge,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    this.minHeight = AppTokens.minTouchTargetSize,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: subtitle != null ? '$label, $subtitle' : label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
          padding: padding,
          decoration: AppTokens.selectionDecoration(isSelected: isSelected),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTokens.textPrimary
                                  : AppTokens.textSecondary,
                              fontSize: AppTokens.fontCardTitle,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: AppTokens.cyan,
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? AppTokens.cyan : AppTokens.textSecondary,
                          fontSize: AppTokens.fontCaption,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                    if (badge != null) ...[
                      const SizedBox(height: 4),
                      badge!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
