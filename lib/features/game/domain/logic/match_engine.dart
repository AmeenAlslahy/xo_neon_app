import 'dart:async';
import '../models/cell_position.dart';
import '../models/game_status.dart';
import '../models/match_config.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import 'game_engine.dart';
import 'win_evaluator.dart';

/// Callback invoked whenever [MatchState] updates.
typedef MatchStateListener = void Function(MatchState state);

/// Authoritative coordinator managing multi-round local matches,
/// scoring stability, round transitions, and chess-clock timers.
class MatchEngine {
  final WinEvaluator evaluator;
  final DateTime Function() clock;
  final List<MatchStateListener> _listeners = [];

  late MatchState _state;
  late GameEngine _roundEngine;

  Timer? _ticker;
  DateTime? _lastTickTime;
  bool _roundResultRecorded = false;

  MatchEngine({
    required MatchConfig config,
    Player startingPlayer = Player.x,
    this.evaluator = const WinEvaluator(),
    this.clock = DateTime.now,
    bool autoStartTimer = true,
  }) {
    _state = MatchState.initial(
      config: config,
      startingPlayer: startingPlayer,
    );

    _roundEngine = GameEngine(
      config: config.boardConfig,
      startingPlayer: startingPlayer,
      evaluator: evaluator,
      clock: clock,
    );

    _lastTickTime = clock();

    if (config.timerConfig.enabled && autoStartTimer) {
      _startTicker();
    }
  }

  MatchState get state => _state;
  MatchConfig get config => _state.config;
  int get currentRound => _state.currentRound;
  int get scoreX => _state.scoreX;
  int get scoreO => _state.scoreO;
  Player get roundStartingPlayer => _state.roundStartingPlayer;
  Player get currentTurnPlayer => _state.roundState.currentPlayer;
  MatchPhase get phase => _state.phase;
  RoundEndReason? get roundEndReason => _state.roundEndReason;
  Player? get roundWinner => _state.roundWinner;
  Player? get matchWinner => _state.matchWinner;
  Duration get remainingTimeX => _state.remainingTimeX;
  Duration get remainingTimeO => _state.remainingTimeO;

  bool get isGameOver => _state.roundState.isGameOver;
  bool get isRoundOver => _state.isRoundOver;
  bool get isMatchOver => _state.isMatchOver;
  bool get isPaused => _state.isPaused;
  bool get isFinalRound => _state.isFinalRound;

  void addListener(MatchStateListener listener) => _listeners.add(listener);
  void removeListener(MatchStateListener listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in List<MatchStateListener>.from(_listeners)) {
      listener(_state);
    }
  }

  /// Starts internal periodic ticker for real-time countdown.
  void _startTicker() {
    _ticker?.cancel();
    _lastTickTime = clock();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      tick();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _lastTickTime = null;
  }

  /// Incremental time update. Can be called automatically by [_ticker]
  /// or manually in unit tests with custom [delta] or sampled [clock].
  void tick([Duration? delta]) {
    if (_state.phase != MatchPhase.inProgress) return;
    if (!_state.isTimerEnabled) return;

    final now = clock();
    final elapsed = delta ??
        (_lastTickTime != null ? now.difference(_lastTickTime!) : Duration.zero);
    _lastTickTime = now;

    if (elapsed <= Duration.zero) return;

    final activePlayer = _state.currentTurnPlayer;
    if (activePlayer == Player.x) {
      final updatedTime = _state.remainingTimeX - elapsed;
      if (updatedTime <= Duration.zero) {
        _state = _state.copyWith(remainingTimeX: Duration.zero);
        _handleTimeout(timedOutPlayer: Player.x);
        return;
      } else {
        _state = _state.copyWith(remainingTimeX: updatedTime);
      }
    } else {
      final updatedTime = _state.remainingTimeO - elapsed;
      if (updatedTime <= Duration.zero) {
        _state = _state.copyWith(remainingTimeO: Duration.zero);
        _handleTimeout(timedOutPlayer: Player.o);
        return;
      } else {
        _state = _state.copyWith(remainingTimeO: updatedTime);
      }
    }

    _notifyListeners();
  }

  /// Handles timeout when a player's chess-clock runs out.
  void _handleTimeout({required Player timedOutPlayer}) {
    if (_roundResultRecorded) return;
    _roundResultRecorded = true;
    _stopTicker();

    final roundWinner = timedOutPlayer.other;
    final newScoreX = roundWinner == Player.x ? _state.scoreX + 1 : _state.scoreX;
    final newScoreO = roundWinner == Player.o ? _state.scoreO + 1 : _state.scoreO;

    // Timeout terminal status for round engine
    final timeoutStatus = GameTimeout(
      timedOutPlayer: timedOutPlayer,
      winner: roundWinner,
    );

    _state = _state.copyWith(
      scoreX: newScoreX,
      scoreO: newScoreO,
      roundWinner: roundWinner,
      roundEndReason: RoundEndReason.timeout,
      phase: MatchPhase.roundEnded,
      roundState: _state.roundState.copyWith(status: timeoutStatus),
    );

    _notifyListeners();
  }

  /// Executes a move at the specified [position].
  ///
  /// Checks for timeout, updates chess-clock, and transitions game state.
  void makeMove(Position position, {DateTime? timestamp}) {
    if (_state.phase != MatchPhase.inProgress) return;

    final moveTimestamp = timestamp ?? clock();

    // 1. Process elapsed time up to move execution
    if (_state.isTimerEnabled) {
      final elapsed = _lastTickTime != null
          ? moveTimestamp.difference(_lastTickTime!)
          : Duration.zero;
      _lastTickTime = moveTimestamp;

      final activePlayer = _state.currentTurnPlayer;
      if (activePlayer == Player.x) {
        final remaining = _state.remainingTimeX - elapsed;
        if (remaining <= Duration.zero) {
          _state = _state.copyWith(remainingTimeX: Duration.zero);
          _handleTimeout(timedOutPlayer: Player.x);
          return;
        }
        _state = _state.copyWith(remainingTimeX: remaining);
      } else {
        final remaining = _state.remainingTimeO - elapsed;
        if (remaining <= Duration.zero) {
          _state = _state.copyWith(remainingTimeO: Duration.zero);
          _handleTimeout(timedOutPlayer: Player.o);
          return;
        }
        _state = _state.copyWith(remainingTimeO: remaining);
      }
    }

    // 2. Execute board move on inner engine
    _roundEngine.makeMove(position, timestamp: moveTimestamp);
    _state = _state.copyWith(roundState: _roundEngine.state);

    // 3. Check for round conclusion
    if (_roundEngine.isGameOver && !_roundResultRecorded) {
      _roundResultRecorded = true;
      _stopTicker();

      if (_roundEngine.isWon) {
        final winner = _roundEngine.winner!;
        final newScoreX = winner == Player.x ? _state.scoreX + 1 : _state.scoreX;
        final newScoreO = winner == Player.o ? _state.scoreO + 1 : _state.scoreO;

        _state = _state.copyWith(
          scoreX: newScoreX,
          scoreO: newScoreO,
          roundWinner: winner,
          roundEndReason: RoundEndReason.win,
          phase: MatchPhase.roundEnded,
        );
      } else if (_roundEngine.isDraw) {
        _state = _state.copyWith(
          roundWinner: null,
          roundEndReason: RoundEndReason.draw,
          phase: MatchPhase.roundEnded,
        );
      }
    }

    _notifyListeners();
  }

  /// Advances to the next round, alternating the starting player,
  /// resetting the board and timers, and preserving player scores.
  ///
  /// If the current round was the final round, concludes the match.
  void nextRound() {
    if (_state.isFinalRound) {
      finalizeMatch();
      return;
    }

    _stopTicker();
    _roundResultRecorded = false;

    final nextRoundNumber = _state.currentRound + 1;
    final nextStarter = _state.roundStartingPlayer.other;

    _roundEngine = GameEngine(
      config: _state.config.boardConfig,
      startingPlayer: nextStarter,
      evaluator: evaluator,
      clock: clock,
    );

    final resetTime = _state.config.timerConfig.durationPerPlayer;

    _state = _state.copyWith(
      currentRound: nextRoundNumber,
      roundStartingPlayer: nextStarter,
      roundState: _roundEngine.state,
      phase: MatchPhase.inProgress,
      roundEndReason: null,
      roundWinner: null,
      remainingTimeX: resetTime,
      remainingTimeO: resetTime,
    );

    _lastTickTime = clock();

    if (_state.isTimerEnabled) {
      _startTicker();
    }

    _notifyListeners();
  }

  /// Concludes the entire match, calculating the overall match winner or draw.
  void finalizeMatch() {
    _stopTicker();

    Player? overallWinner;
    if (_state.scoreX > _state.scoreO) {
      overallWinner = Player.x;
    } else if (_state.scoreO > _state.scoreX) {
      overallWinner = Player.o;
    } else {
      overallWinner = null; // Final Draw
    }

    _state = _state.copyWith(
      phase: MatchPhase.matchEnded,
      matchWinner: overallWinner,
    );

    _notifyListeners();
  }

  /// Pauses active gameplay and freezes timers (e.g. user pause or app backgrounded).
  void pause() {
    if (_state.phase != MatchPhase.inProgress) return;

    if (_state.isTimerEnabled && _lastTickTime != null) {
      // Deduct elapsed slice up to pause instant
      final elapsed = clock().difference(_lastTickTime!);
      if (elapsed > Duration.zero) {
        final active = _state.currentTurnPlayer;
        if (active == Player.x) {
          final rem = _state.remainingTimeX - elapsed;
          _state = _state.copyWith(
            remainingTimeX: rem > Duration.zero ? rem : Duration.zero,
          );
        } else {
          final rem = _state.remainingTimeO - elapsed;
          _state = _state.copyWith(
            remainingTimeO: rem > Duration.zero ? rem : Duration.zero,
          );
        }
      }
    }

    _stopTicker();
    _lastTickTime = null;
    _state = _state.copyWith(phase: MatchPhase.paused);
    _notifyListeners();
  }

  /// Resumes gameplay and timers from paused state.
  void resume() {
    if (_state.phase != MatchPhase.paused) return;

    _lastTickTime = clock();
    _state = _state.copyWith(phase: MatchPhase.inProgress);
    if (_state.isTimerEnabled) {
      _startTicker();
    }
    _notifyListeners();
  }

  /// Resets the current active round's board and clocks,
  /// keeping existing match scores and the starting player of this round intact.
  void resetCurrentRound() {
    _stopTicker();
    _roundResultRecorded = false;

    _roundEngine = GameEngine(
      config: _state.config.boardConfig,
      startingPlayer: _state.roundStartingPlayer,
      evaluator: evaluator,
      clock: clock,
    );

    final resetTime = _state.config.timerConfig.durationPerPlayer;

    _state = _state.copyWith(
      roundState: _roundEngine.state,
      phase: MatchPhase.inProgress,
      roundEndReason: null,
      roundWinner: null,
      remainingTimeX: resetTime,
      remainingTimeO: resetTime,
    );

    _lastTickTime = clock();

    if (_state.isTimerEnabled) {
      _startTicker();
    }

    _notifyListeners();
  }

  /// Starts a brand new match with reset scores (0 - 0) and round 1.
  void restartMatch({MatchConfig? newConfig}) {
    _stopTicker();
    _roundResultRecorded = false;

    final activeConfig = newConfig ?? _state.config;
    _state = MatchState.initial(
      config: activeConfig,
      startingPlayer: Player.x,
    );

    _roundEngine = GameEngine(
      config: activeConfig.boardConfig,
      startingPlayer: Player.x,
      evaluator: evaluator,
      clock: clock,
    );

    _lastTickTime = clock();

    if (activeConfig.timerConfig.enabled) {
      _startTicker();
    }

    _notifyListeners();
  }

  void dispose() {
    _stopTicker();
    _listeners.clear();
  }
}
