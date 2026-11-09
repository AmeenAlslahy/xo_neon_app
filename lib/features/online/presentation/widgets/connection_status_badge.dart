import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../application/connection_status_provider.dart';

/// Small visual indicator badge for live network/Firebase connectivity.
class ConnectionStatusBadge extends ConsumerWidget {
  const ConnectionStatusBadge({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final strings = ref.watch(stringsProvider);

    final (color, label, icon) = switch (status) {
      ConnectionStatus.connected => (
          NeonColors.cyanX,
          strings.connectionConnected,
          Icons.wifi,
        ),
      ConnectionStatus.connecting => (
          NeonColors.amberGold,
          strings.connectionConnecting,
          Icons.wifi_protected_setup,
        ),
      ConnectionStatus.reconnecting => (
          NeonColors.amberGold,
          strings.connectionReconnecting,
          Icons.sync,
        ),
      ConnectionStatus.disconnected => (
          NeonColors.orangeO,
          strings.connectionDisconnected,
          Icons.wifi_off,
        ),
    };

    return Tooltip(
      message: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 10 : 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 1.0,
          ),
          boxShadow: NeonColors.glow(
            color: color,
            blur: 6,
            spread: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: NeonColors.glow(
                  color: color,
                  blur: 4,
                  spread: 0.5,
                ),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
