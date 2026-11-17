import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/app_tokens.dart';

/// Neutral card displaying a 6-character room code with 1-tap copy without glow or extra cyan.
/// Enhanced for UX-DELIGHT-01: copy icon temporarily transforms to checkmark with lightImpact.
class RoomCodeDisplay extends ConsumerStatefulWidget {
  const RoomCodeDisplay({
    super.key,
    required this.code,
    this.onCopied,
  });

  final String code;
  final VoidCallback? onCopied;

  @override
  ConsumerState<RoomCodeDisplay> createState() => _RoomCodeDisplayState();
}

class _RoomCodeDisplayState extends ConsumerState<RoomCodeDisplay> {
  bool _isCopied = false;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyToClipboard(String message) async {
    final cleanCode = widget.code.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    await Clipboard.setData(ClipboardData(text: cleanCode));

    // Sensory haptic feedback on copy
    await Haptics.roomCodeCopied();

    if (mounted) {
      setState(() => _isCopied = true);
      _revertTimer?.cancel();
      _revertTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _isCopied = false);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: AppTokens.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTokens.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTokens.borderSubtle, width: 1.2),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    widget.onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final cleanCode = widget.code.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTokens.borderSubtle, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.roomCodeLabel,
            style: AppTokens.captionStyle,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cleanCode,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppTokens.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: strings.copyCode,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                      key: ValueKey(_isCopied),
                      color: AppTokens.cyan,
                      size: 24,
                    ),
                  ),
                  onPressed: () => _copyToClipboard(strings.codeCopied),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
