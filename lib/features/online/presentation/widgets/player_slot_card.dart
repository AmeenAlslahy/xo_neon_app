import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/app_tokens.dart';

/// Card showing a player slot (Host or Guest) in an online match lobby.
/// Updated for UX-CLARITY-02 & UX-DELIGHT-01:
/// - Neutral cards without persistent glow.
/// - Guest joining triggers lightImpact haptic + 600ms brief gold flash transition.
/// - Identical height skeleton for waiting guest to eliminate layout shift.
class PlayerSlotCard extends StatefulWidget {
  const PlayerSlotCard({
    super.key,
    required this.roleTitle,
    required this.isHost,
    required this.playerName,
    required this.isOccupied,
    required this.isCurrentPlayer,
    required this.waitingText,
    required this.youBadgeText,
  });

  final String roleTitle;
  final bool isHost;
  final String? playerName;
  final bool isOccupied;
  final bool isCurrentPlayer;
  final String waitingText;
  final String youBadgeText;

  @override
  State<PlayerSlotCard> createState() => _PlayerSlotCardState();
}

class _PlayerSlotCardState extends State<PlayerSlotCard> {
  bool _isFlashing = false;
  Timer? _flashTimer;

  @override
  void didUpdateWidget(covariant PlayerSlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Guest slot just transitioned from empty to occupied
    if (!widget.isHost && widget.isOccupied && !oldWidget.isOccupied) {
      Haptics.guestJoined();
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (!reduceMotion) {
        setState(() => _isFlashing = true);
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _isFlashing = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  String _formatPlayerName(String raw) {
    // Transform "Host (1234)" -> "المضيف · 1234" with Unicode isolate
    final match = RegExp(r'Host\s*\((.*?)\)').firstMatch(raw);
    if (match != null) {
      final id = match.group(1) ?? '';
      return 'المضيف · \u2068$id\u2069';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final symbol = widget.isHost ? 'X' : 'O';
    final symbolColor = widget.isHost ? AppTokens.cyan : AppTokens.coral;

    final Color borderColor;
    if (_isFlashing) {
      borderColor = AppTokens.amberGold;
    } else if (widget.isOccupied) {
      borderColor = AppTokens.borderSubtle;
    } else {
      borderColor = AppTokens.borderSubtle.withValues(alpha: 0.6);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _isFlashing
            ? AppTokens.amberGold.withValues(alpha: 0.12)
            : AppTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: _isFlashing ? 1.8 : 1.0,
        ),
        boxShadow: _isFlashing
            ? [
                BoxShadow(
                  color: AppTokens.amberGold.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Symbol Badge (X in Cyan, O in Coral)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: symbolColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: symbolColor.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                symbol,
                style: TextStyle(
                  color: symbolColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Player name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.roleTitle,
                        style: TextStyle(
                          color: symbolColor,
                          fontSize: AppTokens.fontCaption,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.isHost && widget.isOccupied) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTokens.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isArabic ? 'المضيف' : 'Host',
                            style: const TextStyle(
                              color: AppTokens.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (widget.isCurrentPlayer) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTokens.amberGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTokens.amberGold,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.youBadgeText,
                            style: const TextStyle(
                              color: AppTokens.amberGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isOccupied
                      ? (widget.playerName != null
                          ? _formatPlayerName(widget.playerName!)
                          : '')
                      : widget.waitingText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isOccupied
                        ? AppTokens.textPrimary
                        : AppTokens.textSecondary,
                    fontSize: AppTokens.fontBody,
                    fontWeight: widget.isOccupied
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Occupied Status Indicator (Quiet point, no confusing checkmark)
          if (widget.isOccupied) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: symbolColor,
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
