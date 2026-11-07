import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../application/match_controller.dart';
import '../../application/match_providers.dart';
import '../../domain/xo_engine.dart';
import '../widgets/game_grid_widget.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/player_turn_header.dart';
import '../widgets/round_end_banner.dart';

/// Passive screen hosting a cyber-neon local match. All match timing and
/// transition pacing lives in [MatchController] (application layer); this
/// widget watches [matchControllerProvider], renders state, and forwards
/// user intent. Locale/strings come from Riverpod — no prop drilling.
class GameBoardScreen extends ConsumerWidget {
  const GameBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(matchControllerProvider);
    final strings = ref.watch(stringsProvider);
    final matchState = ui.match;
    final roundState = matchState.roundState;
    final boardConfig = ref.watch(matchConfigProvider).boardConfig;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Pacing-only accessibility setting; a plain field, no rebuild needed.
    ref.read(matchControllerProvider.notifier).reduceMotion = reduceMotion;

    // Present the final result dialog exactly once per concluded match.
    ref.listen<MatchUiState>(matchControllerProvider, (previous, next) {
      final justConcluded =
          next.match.isMatchOver && !(previous?.match.isMatchOver ?? false);
      if (justConcluded) {
        _presentFinalMatchDialog(context, ref);
      }
    });

        final isNonFinalRoundEnded = matchState.isRoundOver && !matchState.isFinalRound;
        final isMatchConcluded = matchState.isMatchOver;
        final isPaused = matchState.isPaused;
        final schedulingPaused = ui.isSchedulingPaused;
        // Background-freeze of the transition countdown exposes the same
        // manual resume affordance as an engine pause (no auto-resume).
        final effectivelyPaused = isPaused || schedulingPaused;
        final controller = ref.read(matchControllerProvider.notifier);

    return _AppLifecycleObserver(
      child: PopScope(
        canPop: isMatchConcluded || roundState.moveHistory.isEmpty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final canLeave = await _confirmExitActiveMatch(context, ref);
          if (!context.mounted) return;
          if (canLeave) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: NeonColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: NeonColors.textSecondary),
              tooltip: strings.exitToHome,
              onPressed: () => _onExitPressed(context, ref),
            ),
            title: Text(strings.presetTitle(boardConfig)),
              actions: [
                if (!matchState.isRoundOver || schedulingPaused)
                  IconButton(
                    tooltip: effectivelyPaused ? strings.resumeGame : strings.pauseGame,
                    icon: Icon(
                      effectivelyPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: NeonColors.amberGold,
                    ),
                    onPressed: () {
                      if (effectivelyPaused) {
                        controller.resume();
                      } else {
                        controller.pause();
                      }
                    },
                  ),
              IconButton(
                tooltip: strings.resetGame,
                icon: const Icon(Icons.refresh_rounded, color: NeonColors.cyanX),
                onPressed: () => _onReplayRoundPressed(context, ref),
              ),
            ],
          ),
          body: Container(
            decoration: NeonColors.cyberBackground,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Player Turn HUD with Scores, Rounds, Chess Clocks, and Status
                    PlayerTurnHeader(
                      currentPlayer: roundState.currentPlayer,
                      config: boardConfig,
                      scoreX: matchState.scoreX,
                      scoreO: matchState.scoreO,
                      currentRound: matchState.currentRound,
                      totalRounds: matchState.config.totalRounds,
                      remainingTimeX: matchState.remainingTimeX,
                      remainingTimeO: matchState.remainingTimeO,
                      isTimerEnabled: matchState.isTimerEnabled,
                      isPaused: isPaused,
                      status: roundState.status,
                    ),
                    const SizedBox(height: 10),

                    // Pause Overlay Banner if Match is Paused
                    if (isPaused)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF160E36),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: NeonColors.amberGold, width: 1.5),
                          boxShadow: NeonColors.glow(color: NeonColors.amberGold, blur: 10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pause_circle_filled_rounded, color: NeonColors.amberGold, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.matchPausedDesc,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: NeonColors.amberGold.withValues(alpha: 0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: NeonColors.amberGold),
                                ),
                              ),
                              onPressed: () => controller.resume(),
                              child: Text(
                                strings.resumeGame,
                                style: const TextStyle(
                                  color: NeonColors.amberGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Single unified cyber-neon game board
                    Expanded(
                      child: Center(
                        child: GameGridWidget(
                          config: boardConfig,
                          board: roundState.board,
                          winningLine: roundState.winningLine,
                          allWinningLines: roundState.status is GameWon
                              ? (roundState.status as GameWon).allWinningLines
                              : null,
                          winner: roundState.winner,
                          currentPlayer: roundState.currentPlayer,
                          onCellTap: (position) => _handleCellTap(ref, position),
                        ),
                      ),
                    ),

                    // Non-obscuring Round End Transition Banner
                    if (isNonFinalRoundEnded)
                      RoundEndBanner(
                        matchState: matchState,
                        transitionSecondsRemaining: ui.roundTransitionSecondsRemaining,
                        onNextRound: controller.nextRound,
                      ),

                    const SizedBox(height: 10),

                    // Responsive Bottom Control Bar (No text clipping)
                    if (isMatchConcluded)
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: NeonButton(
                              label: strings.playAgain,
                              icon: Icons.replay_rounded,
                              isSolid: true,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              onPressed: () => _restartMatch(ref),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: NeonButton(
                              label: strings.viewResult,
                              icon: Icons.emoji_events_outlined,
                              isSecondary: true,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              onPressed: () => _presentFinalMatchDialog(context, ref),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: NeonButton(
                              label: strings.exitToHome,
                              icon: Icons.home_outlined,
                              isSecondary: true,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                              onPressed: () => _onExitPressed(context, ref),
                            ),
                          ),
                        ],
                      )
                    else if (isNonFinalRoundEnded)
                      Row(
                        children: [
                          Expanded(
                            child: NeonButton(
                              label: strings.nextRoundNow,
                              icon: Icons.skip_next_rounded,
                              isSolid: true,
                              color: NeonColors.purpleNeon,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              onPressed: controller.nextRound,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NeonButton(
                              label: strings.exitToHome,
                              icon: Icons.home_outlined,
                              isSecondary: true,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              onPressed: () => _onExitPressed(context, ref),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                            Expanded(
                              child: NeonButton(
                                label: effectivelyPaused ? strings.resumeGame : strings.pauseGame,
                                icon: effectivelyPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                isSecondary: true,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                onPressed: () {
                                  if (effectivelyPaused) {
                                    controller.resume();
                                  } else {
                                    controller.pause();
                                  }
                                },
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NeonButton(
                              label: strings.resetGame,
                              icon: Icons.refresh,
                              isSecondary: true,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              onPressed: () => _onReplayRoundPressed(context, ref),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NeonButton(
                              label: strings.exitToHome,
                              icon: Icons.home_outlined,
                              isSecondary: true,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              onPressed: () => _onExitPressed(context, ref),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handles tapping a grid cell, routing to the controller's engine.
  void _handleCellTap(WidgetRef ref, Position position) {
    final controller = ref.read(matchControllerProvider.notifier);
    if (controller.isRoundOver || controller.isPaused) return;
    if (!controller.snapshot.match.roundState.board.isEmpty(position)) return;

    try {
      controller.makeMove(position);
    } on GameException {
      return;
    }
  }

  /// Presents the final match summary dialog.
  void _presentFinalMatchDialog(BuildContext context, WidgetRef ref) {
    final controller = ref.read(matchControllerProvider.notifier);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => GameOverDialog(
        status: controller.snapshot.match.roundState.status,
        isFinalMatchResult: true,
        scoreX: controller.scoreX,
        scoreO: controller.scoreO,
        matchWinner: controller.matchWinner,
        onRematch: () {
          Navigator.of(context).pop();
          _restartMatch(ref);
        },
        onViewBoard: () {
          Navigator.of(context).pop();
        },
        onExit: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Restarts the match with zeroed scores and round 1.
  void _restartMatch(WidgetRef ref) {
    ref.read(matchControllerProvider.notifier).startMatch();
  }

  /// Confirms replay of the active round if moves have been made.
  Future<bool> _confirmReplayActiveRound(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(matchControllerProvider.notifier);
    if (controller.isRoundOver || controller.snapshot.match.roundState.moveHistory.isEmpty) {
      return true;
    }

    final strings = ref.read(stringsProvider);
    final shouldRestart = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF100A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NeonColors.purpleBorder, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: NeonColors.cyanX, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.replayConfirmTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          strings.replayConfirmMessage,
          style: const TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              strings.cancel,
              style: const TextStyle(
                color: NeonColors.cyanX,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              strings.confirmRestart,
              style: const TextStyle(
                color: NeonColors.orangeO,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return shouldRestart ?? false;
  }

  void _onReplayRoundPressed(BuildContext context, WidgetRef ref) async {
    final canRestart = await _confirmReplayActiveRound(context, ref);
    if (!context.mounted) return;
    if (canRestart) {
      ref.read(matchControllerProvider.notifier).resetCurrentRound();
    }
  }

  /// Confirms exit if match is active.
  Future<bool> _confirmExitActiveMatch(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(matchControllerProvider.notifier);
    if (controller.isMatchOver || controller.snapshot.match.roundState.moveHistory.isEmpty) {
      return true;
    }

    final strings = ref.read(stringsProvider);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF100A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NeonColors.purpleBorder, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: NeonColors.amberGold, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.exitDialogTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          strings.exitDialogMessage,
          style: const TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              strings.cancel,
              style: const TextStyle(
                color: NeonColors.cyanX,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              strings.confirmExit,
              style: const TextStyle(
                color: NeonColors.orangeO,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  void _onExitPressed(BuildContext context, WidgetRef ref) async {
    final canLeave = await _confirmExitActiveMatch(context, ref);
    if (!context.mounted) return;
    if (canLeave) {
      Navigator.of(context).pop();
    }
  }
}

/// Pauses the match when the app is backgrounded (lifecycle wiring only —
/// no state management lives here).
class _AppLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;

  const _AppLifecycleObserver({required this.child});

  @override
  ConsumerState<_AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<_AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Approved background policy: freeze the chess clock AND the transition
      // countdown on background, regardless of the match phase (pause()
      // itself no-ops where there is nothing to freeze). A pending final-
      // result presentation is frozen too. Resume stays manual for the
      // countdown: this observer never resumes it.
      ref
          .read(matchControllerProvider.notifier)
          .pause(freezeResultPresentation: true);
    } else if (state == AppLifecycleState.resumed) {
      // Adopted final-result policy: a result frozen by the background is
      // presented immediately on return — no manual resume required. The
      // transition countdown is untouched (stays frozen until manual resume).
      ref.read(matchControllerProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
