import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../domain/xo_engine.dart';

/// Passive banner presented between rounds showing the round outcome, the
/// updated score, and the controller-owned auto-transition countdown.
/// ALL timing lives in [MatchController]; this widget only renders.
class RoundEndBanner extends ConsumerWidget {
  final MatchState matchState;
  final int transitionSecondsRemaining;
  final VoidCallback onNextRound;

  const RoundEndBanner({
    super.key,
    required this.matchState,
    this.transitionSecondsRemaining = 3,
    required this.onNextRound,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = matchState;
    final strings = ref.watch(stringsProvider);
    final isWon = state.roundEndReason == RoundEndReason.win;
    final isTimeout = state.roundEndReason == RoundEndReason.timeout;

    final Color themeColor;
    final String headline;
    final IconData icon;

    if (isTimeout) {
      themeColor = state.roundWinner == Player.x ? NeonColors.cyanX : NeonColors.orangeO;
      headline = strings.timeoutMessage(state.roundWinner!.other.symbol);
      icon = Icons.timer_off_outlined;
    } else if (isWon) {
      themeColor = state.roundWinner == Player.x ? NeonColors.cyanX : NeonColors.orangeO;
      headline = strings.winnerWon(state.roundWinner!.symbol);
      icon = Icons.emoji_events_rounded;
    } else {
      themeColor = NeonColors.amberGold;
      headline = strings.roundDrawMessage;
      icon = Icons.handshake_outlined;
    }

    final seconds = transitionSecondsRemaining > 0 ? transitionSecondsRemaining : 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: themeColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.nextRoundIn(seconds),
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: themeColor.withValues(alpha: 0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: themeColor.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: onNextRound,
            child: Text(
              strings.nextRoundNow,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
