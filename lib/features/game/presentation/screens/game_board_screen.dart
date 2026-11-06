import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/xo_engine.dart';
import '../widgets/game_grid_widget.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/player_turn_header.dart';
import '../widgets/round_end_banner.dart';

/// Screen hosting a cyber-neon local match, driven authoritatively by [MatchEngine].
class GameBoardScreen extends StatefulWidget {
  final MatchConfig matchConfig;
  final bool isArabic;

  GameBoardScreen({
    super.key,
    MatchConfig? matchConfig,
    BoardConfig? config,
    this.isArabic = true,
  }) : matchConfig = matchConfig ??
            MatchConfig(
              boardConfig: config ?? BoardConfig.grid3x3,
              totalRounds: 1,
            );

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> with WidgetsBindingObserver {
  late MatchEngine _engine;
  bool _dialogPresentedForFinalMatch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initEngine();
  }

  void _initEngine([MatchConfig? newConfig]) {
    _engine = MatchEngine(
      config: newConfig ?? widget.matchConfig,
      startingPlayer: Player.x,
    );
    _engine.addListener(_onMatchStateChanged);
    _dialogPresentedForFinalMatch = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.removeListener(_onMatchStateChanged);
    _engine.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_engine.phase == MatchPhase.inProgress) {
        _engine.pause();
      }
    }
  }

  void _onMatchStateChanged(MatchState state) {
    if (!mounted) return;
    setState(() {});

    // When the final round completes, display the final match outcome dialog
    if (state.isMatchOver && !_dialogPresentedForFinalMatch) {
      _dialogPresentedForFinalMatch = true;
      _presentFinalMatchDialog();
    } else if (state.isRoundOver && state.isFinalRound && !_dialogPresentedForFinalMatch) {
      // Allow players to view the board first, then finalize match and show dialog
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      final delay = reduceMotion ? const Duration(milliseconds: 400) : const Duration(milliseconds: 1200);

      Future.delayed(delay, () {
        if (!mounted) return;
        if (!_dialogPresentedForFinalMatch) {
          _dialogPresentedForFinalMatch = true;
          _engine.finalizeMatch();
          _presentFinalMatchDialog();
        }
      });
    }
  }

  /// Handles tapping a grid cell, routing to authoritative [MatchEngine].
  void _handleCellTap(Position position) {
    if (_engine.isRoundOver || _engine.isPaused) return;
    if (!_engine.state.roundState.board.isEmpty(position)) return;

    try {
      _engine.makeMove(position);
    } on GameException {
      return;
    }
  }

  /// Presents the final match summary dialog.
  void _presentFinalMatchDialog() {
    final strings = AppStrings(isArabic: widget.isArabic);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => GameOverDialog(
        status: _engine.state.roundState.status,
        isFinalMatchResult: true,
        scoreX: _engine.scoreX,
        scoreO: _engine.scoreO,
        matchWinner: _engine.matchWinner,
        strings: strings,
        onRematch: () {
          Navigator.of(context).pop();
          _restartMatch();
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
  void _restartMatch() {
    setState(() {
      _dialogPresentedForFinalMatch = false;
      _engine.restartMatch();
    });
  }

  /// Advances to the next round in a multi-round match.
  void _advanceNextRound() {
    setState(() {
      _engine.nextRound();
    });
  }

  /// Confirms replay of the active round if moves have been made.
  Future<bool> _confirmReplayActiveRound() async {
    if (_engine.isRoundOver || _engine.state.roundState.moveHistory.isEmpty) {
      return true;
    }

    final strings = AppStrings(isArabic: widget.isArabic);
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

  void _onReplayRoundPressed() async {
    final canRestart = await _confirmReplayActiveRound();
    if (!mounted) return;
    if (canRestart) {
      _engine.resetCurrentRound();
    }
  }

  /// Confirms exit if match is active.
  Future<bool> _confirmExitActiveMatch() async {
    if (_engine.isMatchOver || _engine.state.roundState.moveHistory.isEmpty) {
      return true;
    }

    final strings = AppStrings(isArabic: widget.isArabic);
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

  void _onExitPressed() async {
    final canLeave = await _confirmExitActiveMatch();
    if (!mounted) return;
    if (canLeave) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(isArabic: widget.isArabic);
    final matchState = _engine.state;
    final roundState = matchState.roundState;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final isNonFinalRoundEnded = matchState.isRoundOver && !matchState.isFinalRound;
    final isMatchConcluded = matchState.isMatchOver;
    final isPaused = matchState.isPaused;

    return PopScope(
      canPop: isMatchConcluded || roundState.moveHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canLeave = await _confirmExitActiveMatch();
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
            onPressed: _onExitPressed,
          ),
          title: Text(strings.presetTitle(widget.matchConfig.boardConfig)),
          actions: [
            if (!matchState.isRoundOver)
              IconButton(
                tooltip: isPaused ? strings.resumeGame : strings.pauseGame,
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: NeonColors.amberGold,
                ),
                onPressed: () {
                  if (isPaused) {
                    _engine.resume();
                  } else {
                    _engine.pause();
                  }
                },
              ),
            IconButton(
              tooltip: strings.resetGame,
              icon: const Icon(Icons.refresh_rounded, color: NeonColors.cyanX),
              onPressed: _onReplayRoundPressed,
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
                    config: widget.matchConfig.boardConfig,
                    scoreX: matchState.scoreX,
                    scoreO: matchState.scoreO,
                    currentRound: matchState.currentRound,
                    totalRounds: matchState.config.totalRounds,
                    remainingTimeX: matchState.remainingTimeX,
                    remainingTimeO: matchState.remainingTimeO,
                    isTimerEnabled: matchState.isTimerEnabled,
                    isPaused: isPaused,
                    status: roundState.status,
                    strings: strings,
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
                            onPressed: () => _engine.resume(),
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
                        config: widget.matchConfig.boardConfig,
                        board: roundState.board,
                        winningLine: roundState.winningLine,
                        allWinningLines: roundState.status is GameWon
                            ? (roundState.status as GameWon).allWinningLines
                            : null,
                        winner: roundState.winner,
                        currentPlayer: roundState.currentPlayer,
                        onCellTap: _handleCellTap,
                        isArabic: widget.isArabic,
                      ),
                    ),
                  ),

                  // Non-obscuring Round End Transition Banner
                  if (isNonFinalRoundEnded)
                    RoundEndBanner(
                      matchState: matchState,
                      onNextRound: _advanceNextRound,
                      strings: strings,
                      reduceMotion: reduceMotion,
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
                            onPressed: _restartMatch,
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
                            onPressed: _presentFinalMatchDialog,
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
                            onPressed: _onExitPressed,
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
                            onPressed: _advanceNextRound,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NeonButton(
                            label: strings.exitToHome,
                            icon: Icons.home_outlined,
                            isSecondary: true,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            onPressed: _onExitPressed,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: NeonButton(
                            label: isPaused ? strings.resumeGame : strings.pauseGame,
                            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            isSecondary: true,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            onPressed: () {
                              if (isPaused) {
                                _engine.resume();
                              } else {
                                _engine.pause();
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
                            onPressed: _onReplayRoundPressed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NeonButton(
                            label: strings.exitToHome,
                            icon: Icons.home_outlined,
                            isSecondary: true,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            onPressed: _onExitPressed,
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
    );
  }
}
