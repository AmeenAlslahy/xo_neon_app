import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Sticky bottom CTA container pinned inside SafeArea outside of the scroll area.
/// Displays an optional live summary text above a full-width primary button.
class StickyBottomBar extends StatelessWidget {
  final String? summaryText;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const StickyBottomBar({
    super.key,
    this.summaryText,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.background.withValues(alpha: 0.96),
        border: const Border(
          top: BorderSide(color: AppTokens.borderSubtle, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summaryText != null && summaryText!.trim().isNotEmpty) ...[
                Text(
                  summaryText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: AppTokens.fontBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
