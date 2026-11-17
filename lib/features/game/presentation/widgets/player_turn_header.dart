import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/xo_engine.dart';
import 'neon_o_widget.dart';
import 'neon_x_widget.dart';

/// Top bar displaying players, active turn indicator, scores,
/// multi-round progression, chess clocks, and board win rule.
/// Updated for UX-CLARITY-02 with prominent scores (22/700), unified names, and single turn indicator.
class PlayerTurnHeader extends ConsumerWidget {
  final Player currentPlayer;
  final BoardConfig config;
  final int scoreX;
  final int scoreO;
  final GameStatus? status;
  final int currentRound;
  final int totalRounds;
  final Duration? remainingTimeX;
  final Duration? remainingTimeO;
  final bool isTimerEnabled;
  final bool isPaused;
  final bool isSystemThinking;

  const PlayerTurnHeader({
    super.key,
    required this.currentPlayer,
    required this.config,
    this.scoreX = 0,
    this.scoreO = 0,
    this.status,
    this.currentRound = 1,
    this.totalRounds = 1,
    this.remainingTimeX,
    this.remainingTimeO,
    this.isTimerEnabled = false,
    this.isPaused = false,
    this.isSystemThinking = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final isGameOver = status?.isTerminal ?? false;
    final isWon = status is GameWon;
    final isTimeout = status is GameTimeout;
    final winner = isWon
        ? (status as GameWon).winner
        : (isTimeout ? (status as GameTimeout).winner : null);
    final isDraw = status is GameDraw;

    final isXActive = !isGameOver && !isPaused && currentPlayer == Player.x;
    final isOActive = !isGameOver && !isPaused && currentPlayer == Player.o;
    final isXWinner = (isWon || isTimeout) && winner == Player.x;
    final isOWinner = (isWon || isTimeout) && winner == Player.o;

    final Color statusColor;
    if (isPaused) {
      statusColor = AppTokens.amberGold;
    } else if (isWon || isTimeout) {
      statusColor = winner == Player.x ? AppTokens.cyan : AppTokens.coral;
    } else if (isDraw) {
      statusColor = AppTokens.amberGold;
    } else {
      statusColor = isXActive ? AppTokens.cyan : AppTokens.coral;
    }

    final isArabic = strings.isArabic;
    final String turnHeaderSemantics;
    if (isArabic) {
      turnHeaderSemantics = isGameOver
          ? (isWon || isTimeout
              ? 'نهاية المباراة. الفائز: ${winner!.symbol}. النتيجة X: $scoreX، النتيجة O: $scoreO'
              : 'نهاية المباراة. تعادل. النتيجة X: $scoreX، النتيجة O: $scoreO')
          : 'نتائج اللاعبين والدور. الدور الحالي: ${currentPlayer.symbol}. النتيجة X: $scoreX، النتيجة O: $scoreO';
    } else {
      turnHeaderSemantics = isGameOver
          ? (isWon || isTimeout
              ? 'Game over. Winner: ${winner!.symbol}. Score X: $scoreX, Score O: $scoreO'
              : 'Game over. Draw. Score X: $scoreX, Score O: $scoreO')
          : 'Player Scores and Turn. Active: ${currentPlayer.symbol}. Score X: $scoreX, Score O: $scoreO';
    }

    return Semantics(
      container: true,
      label: turnHeaderSemantics,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player X Card
          Expanded(
            flex: 5,
            child: _buildPlayerCard(
              player: Player.x,
              label: strings.playerX,
              score: scoreX,
              isActive: isXActive,
              isWinner: isXWinner,
              color: AppTokens.cyan,
              timeRemaining: remainingTimeX,
              isTimerEnabled: isTimerEnabled,
              strings: strings,
            ),
          ),
          const SizedBox(width: 8),

          // Center Status & Round Info Badge
          Expanded(
            flex: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Round progression if multi-round
                if (totalRounds > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTokens.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        strings.roundProgress(currentRound, totalRounds),
                        style: const TextStyle(
                          color: AppTokens.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                // Center Outcome/Status Pill (only when paused, game over, or system thinking)
                if (isPaused || isGameOver || isSystemThinking)
                  AnimatedContainer(
                    duration: AppMotion.turnSwitch,
                    curve: AppMotion.enter,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor,
                        width: 1.5,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isPaused) ...[
                            const Icon(
                              Icons.pause_circle_outline_rounded,
                              size: 14,
                              color: AppTokens.amberGold,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.matchPaused,
                              style: const TextStyle(
                                color: AppTokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else if (isTimeout) ...[
                            const Icon(
                              Icons.timer_off_outlined,
                              size: 14,
                              color: AppTokens.amberGold,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.timeoutMessage(winner!.other.symbol),
                              style: const TextStyle(
                                color: AppTokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else if (isWon) ...[
                            Icon(
                              Icons.emoji_events_rounded,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.winnerWon(winner!.symbol),
                              style: const TextStyle(
                                color: AppTokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else if (isDraw) ...[
                            const Icon(
                              Icons.handshake_outlined,
                              size: 14,
                              color: AppTokens.amberGold,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.drawStatus,
                              style: const TextStyle(
                                color: AppTokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else if (isSystemThinking) ...[
                            const Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: AppTokens.amberGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              strings.systemThinking,
                              style: const TextStyle(
                                color: AppTokens.amberGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Match Rule Info Badge (Board size + required win streak)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTokens.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 12,
                          color: AppTokens.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          strings.boardInfo(config.rows, config.winStreak),
                          style: const TextStyle(
                            color: AppTokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Player O Card
          Expanded(
            flex: 5,
            child: _buildPlayerCard(
              player: Player.o,
              label: strings.playerO,
              score: scoreO,
              isActive: isOActive,
              isWinner: isOWinner,
              color: AppTokens.coral,
              timeRemaining: remainingTimeO,
              isTimerEnabled: isTimerEnabled,
              strings: strings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required Player player,
    required String label,
    required int score,
    required bool isActive,
    bool isWinner = false,
    required Color color,
    Duration? timeRemaining,
    bool isTimerEnabled = false,
    required AppStrings strings,
  }) {
    final isLowTime = isTimerEnabled &&
        timeRemaining != null &&
        timeRemaining.inSeconds <= 10 &&
        timeRemaining > Duration.zero;
    final isTimeOut =
        isTimerEnabled && timeRemaining != null && timeRemaining <= Duration.zero;
    final isHighlighted = isActive || isWinner;

    return AnimatedContainer(
      duration: AppMotion.turnSwitch,
      curve: AppMotion.enter,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.10) : AppTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? color : AppTokens.borderSubtle,
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: isHighlighted ? NeonColors.glow(color: color, blur: 8) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Player identity header (icon + name + optional active turn badge)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                player == Player.x
                    ? const NeonXWidget(size: 16, hasGlow: false)
                    : const NeonOWidget(size: 16, hasGlow: false),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isHighlighted ? AppTokens.textPrimary : AppTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.isArabic ? 'الدور الآن' : 'Turn',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          player.symbol,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isWinner) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.star_rounded, size: 12, color: AppTokens.amberGold),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Prominent Score Display (22/700)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$score',
              style: TextStyle(
                color: isHighlighted ? AppTokens.textPrimary : AppTokens.textSecondary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Chess-Clock Countdown Badge (if timer enabled)
          if (isTimerEnabled && timeRemaining != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isTimeOut
                    ? AppTokens.coral.withValues(alpha: 0.35)
                    : (isLowTime
                        ? AppTokens.amberGold.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTimeOut
                      ? AppTokens.coral
                      : (isLowTime ? AppTokens.amberGold : color.withValues(alpha: 0.4)),
                  width: isLowTime ? 1.4 : 0.8,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLowTime ? Icons.warning_amber_rounded : Icons.timer_outlined,
                      size: 10,
                      color: isLowTime
                          ? AppTokens.amberGold
                          : (isActive ? Colors.white : AppTokens.textSecondary),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      strings.formatDuration(timeRemaining),
                      style: TextStyle(
                        color: isLowTime
                            ? AppTokens.amberGold
                            : (isActive ? Colors.white : AppTokens.textSecondary),
                        fontSize: 11,
                        fontWeight: isLowTime ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
