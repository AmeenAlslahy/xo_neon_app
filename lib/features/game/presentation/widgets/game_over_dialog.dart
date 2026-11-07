import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/xo_engine.dart';
import 'neon_o_widget.dart';
import 'neon_x_widget.dart';

/// Modal dialog presented when a round or an entire match concludes,
/// supporting both intermediate round results and overall match victory/draw summaries.
class GameOverDialog extends ConsumerWidget {
  final GameStatus status;
  final VoidCallback onRematch;
  final VoidCallback onExit;
  final VoidCallback? onViewBoard;
  final bool isFinalMatchResult;
  final int scoreX;
  final int scoreO;
  final Player? matchWinner;

  const GameOverDialog({
    super.key,
    required this.status,
    required this.onRematch,
    required this.onExit,
    this.onViewBoard,
    this.isFinalMatchResult = false,
    this.scoreX = 0,
    this.scoreO = 0,
    this.matchWinner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final isWon = isFinalMatchResult
        ? matchWinner != null
        : (status is GameWon || status is GameTimeout);

    final winner = isFinalMatchResult
        ? matchWinner
        : (status is GameWon
            ? (status as GameWon).winner
            : (status is GameTimeout ? (status as GameTimeout).winner : null));

    final isTimeout = !isFinalMatchResult && status is GameTimeout;

    final themeColor = isWon
        ? (winner == Player.x ? NeonColors.cyanX : NeonColors.orangeO)
        : NeonColors.amberGold;

    return Dialog(
      backgroundColor: const Color(0xFF100A24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: themeColor, width: 2.2),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF100A24),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Glyphs & Iconography
            if (isFinalMatchResult) ...[
              if (isWon) ...[
                winner == Player.x
                    ? const NeonXWidget(size: 56, isWinning: true)
                    : const NeonOWidget(size: 56, isWinning: true),
                const SizedBox(height: 12),
                Text(
                  strings.finalMatchTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    strings.matchWinnerIs(
                      winner!.symbol,
                      winner == Player.x ? scoreX : scoreO,
                      winner == Player.x ? scoreO : scoreX,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 54,
                  color: NeonColors.amberGold,
                ),
                const SizedBox(height: 12),
                Text(
                  strings.finalMatchTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: NeonColors.amberGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NeonColors.amberGold.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    strings.matchDrawResult(scoreX),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: NeonColors.amberGold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ] else if (isTimeout) ...[
              const Icon(
                Icons.timer_off_outlined,
                size: 54,
                color: NeonColors.amberGold,
              ),
              const SizedBox(height: 12),
              Text(
                strings.timeoutLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  strings.timeoutMessage(winner!.other.symbol),
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else if (isWon) ...[
              winner == Player.x
                  ? const NeonXWidget(size: 60, isWinning: true)
                  : const NeonOWidget(size: 60, isWinning: true),
              const SizedBox(height: 14),
              Text(
                strings.victoryTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  strings.winnerIs(winner!.symbol),
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else ...[
              const Icon(
                Icons.handshake_outlined,
                size: 56,
                color: NeonColors.amberGold,
              ),
              const SizedBox(height: 14),
              Text(
                strings.drawTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.drawSubtitle,
                style: const TextStyle(
                  color: NeonColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Primary Action: Rematch with Solid High-Contrast Styling
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                label: strings.playAgain,
                icon: Icons.replay_rounded,
                isSolid: true,
                color: themeColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                onPressed: onRematch,
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Actions: View Board & Return Home
            Row(
              children: [
                if (onViewBoard != null) ...[
                  Expanded(
                    child: NeonButton(
                      label: strings.viewBoard,
                      icon: Icons.visibility_outlined,
                      isSecondary: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      onPressed: onViewBoard,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: NeonButton(
                    label: strings.exitToHome,
                    icon: Icons.home_outlined,
                    isSecondary: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    onPressed: onExit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
