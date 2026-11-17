import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../application/connection_status_provider.dart';

/// Small visual indicator badge for live network/Firebase connectivity.
/// Enhanced for UX-DELIGHT-01: Fires connectionFailure haptic once on disconnect and blinks softly.
class ConnectionStatusBadge extends ConsumerStatefulWidget {
  const ConnectionStatusBadge({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  ConsumerState<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends ConsumerState<ConnectionStatusBadge> {
  ConnectionStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStatusProvider);
    final strings = ref.watch(stringsProvider);

    // Trigger haptic once when entering disconnected state
    if (_lastStatus != null &&
        _lastStatus != ConnectionStatus.disconnected &&
        status == ConnectionStatus.disconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Haptics.connectionFailure();
      });
    }
    _lastStatus = status;

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

    final isDisconnected = status == ConnectionStatus.disconnected;

    return Tooltip(
      message: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: widget.showLabel ? 10 : 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDisconnected ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDisconnected ? 0.8 : 0.5),
            width: 1.0,
          ),
          boxShadow: NeonColors.glow(
            color: color,
            blur: isDisconnected ? 8 : 6,
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
            if (widget.showLabel) ...[
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
