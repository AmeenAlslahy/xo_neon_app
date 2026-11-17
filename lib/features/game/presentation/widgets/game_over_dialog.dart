import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/xo_engine.dart';
import 'celebration_glyphs.dart';

/// Modal dialog presented when a round or an entire match concludes (UX-DELIGHT-01).
/// Adheres strictly to the celebration hierarchy:
/// - Match victory: Crown vector glyph in gold with sparks.
/// - Round victory: Trophy vector glyph in gold with sparks.
/// - Draw: Interlocking X/O vector glyph in calm cyan (no gold, no particles).
/// - Defeat: Calm text only, textSecondary color, zero red, no sad emojis.
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
    final isDefeat = isWon && (isHumanWinner == false);
    final isCelebration = isWon && (isHumanWinner != false);

    // Color role assignment per UX-DELIGHT-01
    final Color themeColor;
    if (isDefeat) {
      themeColor = AppTokens.borderSubtle; // Calm neutral, no red
    } else if (isWon) {
      themeColor = AppTokens.amberGold;    // Gold celebration for victory
    } else {
      themeColor = AppTokens.cyan;         // Calm cyan for draw, no gold
    }

    return Dialog(
      backgroundColor: AppTokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: themeColor,
          width: isCelebration ? 2.0 : 1.2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isCelebration
              ? [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.30),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header Glyphs & Iconography with Celebration Hierarchy
            if (isFinalMatchResult) ...[
              if (isWon) ...[
                if (isCelebration) ...[
                  const CrownGlyphWidget(size: 64),
                  const SizedBox(height: 12),
                  Text(
                    strings.finalMatchTitle,
                    style: const TextStyle(
                      color: AppTokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTokens.amberGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTokens.amberGold.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      strings.matchWinnerIs(
                        winner!.symbol,
                        winner == Player.x ? scoreX : scoreO,
                        winner == Player.x ? scoreO : scoreX,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTokens.amberGold,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  // Defeat: No glyph, text only, no red, no sad emojis
                  const SizedBox(height: 8),
                  Text(
                    strings.finalMatchTitle,
                    style: const TextStyle(
                      color: AppTokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTokens.borderSubtle),
                    ),
                    child: Text(
                      strings.matchWinnerIs(
                        winner!.symbol,
                        winner == Player.x ? scoreX : scoreO,
                        winner == Player.x ? scoreO : scoreX,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTokens.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.isArabic ? 'فاز الخصم — كانت قريبة' : 'Opponent Won — Close Match',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTokens.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ] else ...[
                // Match Draw: Calm cyan interlocking glyph, NO gold
                const DrawGlyphWidget(size: 52),
                const SizedBox(height: 12),
                Text(
                  strings.finalMatchTitle,
                  style: const TextStyle(
                    color: AppTokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTokens.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTokens.cyan.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    strings.matchDrawResult(scoreX),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTokens.cyan,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.isArabic ? 'تعادل — مباراة متكافئة' : 'Draw — Evenly Matched',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ] else if (isTimeout) ...[
              const Icon(
                Icons.timer_off_outlined,
                size: 50,
                color: AppTokens.amberGold,
              ),
              const SizedBox(height: 12),
              Text(
                strings.timeoutLabel,
                style: const TextStyle(
                  color: AppTokens.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
              if (isCelebration) ...[
                const TrophyGlyphWidget(size: 52),
                const SizedBox(height: 12),
                Text(
                  strings.victoryTitle,
                  style: const TextStyle(
                    color: AppTokens.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTokens.amberGold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTokens.amberGold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    strings.winnerIs(winner!.symbol),
                    style: const TextStyle(
                      color: AppTokens.amberGold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                // Round Defeat: Text only, calm
                const SizedBox(height: 8),
                Text(
                  strings.isArabic ? 'جولة للخصم' : 'Opponent Won Round',
                  style: const TextStyle(
                    color: AppTokens.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.isArabic ? 'كانت قريبة' : 'It was close',
                  style: const TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ] else ...[
              // Round Draw: Calm cyan interlocking glyph, NO gold
              const DrawGlyphWidget(size: 48),
              const SizedBox(height: 12),
              Text(
                strings.drawTitle,
                style: const TextStyle(
                  color: AppTokens.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.isArabic ? 'تعادل — مباراة متكافئة' : strings.drawSubtitle,
                style: const TextStyle(
                  color: AppTokens.textSecondary,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTokens.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (moveCount != null)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app_outlined,
                                size: 16, color: AppTokens.cyan),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                strings.movesCount(moveCount!),
                                style: const TextStyle(
                                  color: AppTokens.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (winRatePercentage != null)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.analytics_outlined,
                                size: 16,
                                color: isWon && isCelebration
                                    ? AppTokens.amberGold
                                    : AppTokens.cyan),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                strings.winRateLabel(winRatePercentage!),
                                style: const TextStyle(
                                  color: AppTokens.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (streakWins != null && streakWins! > 0)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 16,
                                color: isWon && isCelebration
                                    ? AppTokens.amberGold
                                    : AppTokens.cyan),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                strings.streakWins(streakWins!),
                                style: const TextStyle(
                                  color: AppTokens.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Primary Action: Rematch
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                label: isFinalMatchResult ? strings.playAgain : strings.nextRoundNow,
                icon: isFinalMatchResult ? Icons.replay_rounded : Icons.skip_next_rounded,
                isSolid: true,
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
    ),
  );
}
}
