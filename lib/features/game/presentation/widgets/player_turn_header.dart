import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../domain/xo_engine.dart';
import 'neon_o_widget.dart';
import 'neon_x_widget.dart';

/// Top bar displaying players, active turn / terminal outcome indicator, scores,
/// multi-round progression, chess clocks, and board win rule.
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
      statusColor = NeonColors.amberGold;
    } else if (isWon || isTimeout) {
      statusColor = winner == Player.x ? NeonColors.cyanX : NeonColors.orangeO;
    } else if (isDraw) {
      statusColor = NeonColors.amberGold;
    } else {
      statusColor = isXActive ? NeonColors.cyanX : NeonColors.orangeO;
    }

    return Semantics(
      container: true,
      label: isGameOver
          ? (isWon || isTimeout
              ? 'Game over. Winner: ${winner!.symbol}. Score X: $scoreX, Score O: $scoreO'
              : 'Game over. Draw. Score X: $scoreX, Score O: $scoreO')
          : 'Player Scores and Turn. Active: ${currentPlayer.symbol}. Score X: $scoreX, Score O: $scoreO',
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
              isActive: isXActive || isXWinner,
              isWinner: isXWinner,
              color: NeonColors.cyanX,
              timeRemaining: remainingTimeX,
              isTimerEnabled: isTimerEnabled,
              strings: strings,
            ),
          ),
          const SizedBox(width: 6),

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
                      color: NeonColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: NeonColors.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        strings.roundProgress(currentRound, totalRounds),
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                // Active Turn, Paused, or Terminal Outcome Pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor,
                      width: 1.5,
                    ),
                    boxShadow: (!isGameOver && !isPaused)
                        ? NeonColors.glow(color: statusColor, blur: 8)
                        : null,
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
                            color: NeonColors.amberGold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.matchPaused,
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ] else if (isTimeout) ...[
                          const Icon(
                            Icons.timer_off_outlined,
                            size: 14,
                            color: NeonColors.amberGold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.timeoutMessage(winner!.other.symbol),
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
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
                              color: NeonColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ] else if (isDraw) ...[
                          const Icon(
                            Icons.handshake_outlined,
                            size: 14,
                            color: NeonColors.amberGold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.drawStatus,
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ] else ...[
                          Text(
                            strings.currentTurn,
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentPlayer.symbol,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (isSystemThinking) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: NeonColors.amberGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              strings.systemThinking,
                              style: const TextStyle(
                                color: NeonColors.amberGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Match Rule Info Badge (Board size + required win streak)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NeonColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: NeonColors.borderSubtle,
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
                          size: 11,
                          color: NeonColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          strings.boardInfo(config.rows, config.winStreak),
                          style: const TextStyle(
                            color: NeonColors.textSecondary,
                            fontSize: 11,
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
          const SizedBox(width: 6),

          // Player O Card
          Expanded(
            flex: 5,
            child: _buildPlayerCard(
              player: Player.o,
              label: strings.playerO,
              score: scoreO,
              isActive: isOActive || isOWinner,
              isWinner: isOWinner,
              color: NeonColors.orangeO,
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.18) : NeonColors.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? color : NeonColors.borderSubtle,
          width: isActive ? 1.8 : 1.0,
        ),
        boxShadow: isActive ? NeonColors.glow(color: color, blur: 12) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                player == Player.x
                    ? const NeonXWidget(size: 18)
                    : const NeonOWidget(size: 18),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isWinner) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.star_rounded, size: 12, color: NeonColors.amberGold),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${strings.scoreLabel}: ',
                  style: const TextStyle(
                    color: NeonColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: isActive ? Colors.white : NeonColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Chess-Clock Countdown Badge (if timer enabled)
          if (isTimerEnabled && timeRemaining != null) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isTimeOut
                    ? NeonColors.orangeO.withValues(alpha: 0.35)
                    : (isLowTime
                        ? NeonColors.amberGold.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTimeOut
                      ? NeonColors.orangeO
                      : (isLowTime ? NeonColors.amberGold : color.withValues(alpha: 0.4)),
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
                          ? NeonColors.amberGold
                          : (isActive ? Colors.white : NeonColors.textSecondary),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      strings.formatDuration(timeRemaining),
                      style: TextStyle(
                        color: isLowTime
                            ? NeonColors.amberGold
                            : (isActive ? Colors.white : NeonColors.textSecondary),
                        fontSize: 10,
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
