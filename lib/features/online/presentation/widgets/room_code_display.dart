import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';

/// Cyber-neon card displaying a 6-character room code with 1-tap copy.
class RoomCodeDisplay extends ConsumerWidget {
  const RoomCodeDisplay({
    super.key,
    required this.code,
    this.onCopied,
  });

  final String code;
  final VoidCallback? onCopied;

  Future<void> _copyToClipboard(BuildContext context, String message) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: NeonColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: NeonColors.cyanX, width: 1.2),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    onCopied?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonColors.cyanX, width: 1.5),
        boxShadow: NeonColors.glow(color: NeonColors.cyanX, blur: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.roomCodeLabel,
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: NeonColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: strings.copyCode,
                icon: const Icon(
                  Icons.copy_rounded,
                  color: NeonColors.cyanX,
                  size: 24,
                ),
                onPressed: () => _copyToClipboard(context, strings.codeCopied),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
