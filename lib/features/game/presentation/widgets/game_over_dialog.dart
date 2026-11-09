import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/xo_engine.dart';
import 'neon_o_widget.dart';
import 'neon_x_widget.dart';

/// Modal dialog presented when a round or an entire match concludes,
/// supporting intermediate round results, overall match victory/draw summaries,
/// moderated celebration glow, statistics, and motivational feedback.
class GameOverDialog extends ConsumerWidget {
  final GameStatus status;
  final VoidCallback onRematch;
  final VoidCallback onExit;
  final VoidCallback? onViewBoard;
  final bool isFinalMatchResult;
  final int scoreX;
  final int scoreO;
  final Player? matchWinner;
  final int? moveCount;
  final bool? isHumanWinner;
  final int? winRatePercentage;
  final int? streakWins;
  final String? difficultyTitle;

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
    this.moveCount,
    this.isHumanWinner,
    this.winRatePercentage,
    this.streakWins,
    this.difficultyTitle,
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

    // Preserves distinct X (Cyan), O (Coral), or Draw (Gold) identity
    final themeColor = isWon
        ? (winner == Player.x ? NeonColors.cyanX : NeonColors.orangeO)
        : NeonColors.amberGold;

    final isCelebration = isWon && (isHumanWinner != false);

    return Dialog(
      backgroundColor: NeonColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: themeColor, width: 2.0),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: NeonColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: isCelebration ? 0.35 : 0.2),
              blurRadius: isCelebration ? 16 : 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Glyphs & Iconography with Celebration Glow
            if (isFinalMatchResult) ...[
              if (isWon) ...[
                if (isCelebration)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.3),
                          blurRadius: 14,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: winner == Player.x
                        ? const NeonXWidget(size: 60, isWinning: true)
                        : const NeonOWidget(size: 60, isWinning: true),
                  )
                else
                  winner == Player.x
                      ? const NeonXWidget(size: 56, isWinning: true)
                      : const NeonOWidget(size: 56, isWinning: true),
                const SizedBox(height: 12),
                Text(
                  strings.finalMatchTitle,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: themeColor.withValues(alpha: 0.6)),
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
                if (isHumanWinner == false) ...[
                  const SizedBox(height: 8),
                  Text(
                    strings.defeatEncouragement,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: NeonColors.amberGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                    color: NeonColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: NeonColors.amberGold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: NeonColors.amberGold.withValues(alpha: 0.6)),
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
                  color: NeonColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.16),
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
                  color: NeonColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.16),
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
                  color: NeonColors.textPrimary,
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

            // Match Statistics Badge (Moves, Win Rate, Streak)
            if (moveCount != null ||
                winRatePercentage != null ||
                streakWins != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: NeonColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NeonColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (moveCount != null)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_outlined,
                              size: 16, color: NeonColors.cyanX),
                          const SizedBox(height: 2),
                          Text(
                            strings.movesCount(moveCount!),
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    if (winRatePercentage != null)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.analytics_outlined,
                              size: 16, color: NeonColors.amberGold),
                          const SizedBox(height: 2),
                          Text(
                            strings.winRateLabel(winRatePercentage!),
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    if (streakWins != null && streakWins! > 0)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 16, color: NeonColors.orangeO),
                          const SizedBox(height: 2),
                          Text(
                            strings.streakWins(streakWins!),
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Primary Action: Rematch with Solid Cyan High-Contrast Styling
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                label: strings.playAgain,
                icon: Icons.replay_rounded,
                isSolid: true,
                color: NeonColors.cyanX,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 11),
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
