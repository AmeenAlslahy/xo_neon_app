import '../models/cell_position.dart';
import '../models/game_status.dart';
import '../models/match_config.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import '../time/time_source.dart';
import 'game_engine.dart';
import 'win_evaluator.dart';

/// Callback invoked whenever [MatchState] updates.
typedef MatchStateListener = void Function(MatchState state);

/// Authoritative rules and state machine for multi-round local matches:
/// scoring stability, round transitions, and chess-clock accounting.
///
/// Purity contract:
/// - This class schedules NO timers. The application layer (`MatchController`)
///   owns all scheduling and drives [tick] pulses whenever it wants.
/// - All chess-clock time flows through the injected monotonic [timeSource];
///   wall-clock `DateTime` values ([wallClock], [Move.timestamp]) are
///   display/log metadata only and NEVER influence remaining time.
class MatchEngine {
  final WinEvaluator evaluator;

  /// Monotonic time source driving every chess-clock deduction.
  final TimeSource timeSource;

  /// Optional wall-clock sampler used exclusively to stamp [Move] records
  /// for display/logging. Never used for countdown math.
  final DateTime Function()? wallClock;

  final List<MatchStateListener> _listeners = [];

  late MatchState _state;
  late GameEngine _roundEngine;

  /// Monotonic anchor of the last processed time instant.
  /// Null while the clock is suspended (paused / round concluded).
  Duration? _lastAnchor;
  bool _roundResultRecorded = false;

  MatchEngine({
    required MatchConfig config,
    Player startingPlayer = Player.x,
    this.evaluator = const WinEvaluator(),
    TimeSource? timeSource,
    this.wallClock,
  }) : timeSource = timeSource ?? StopwatchTimeSource() {
    _state = MatchState.initial(
      config: config,
      startingPlayer: startingPlayer,
    );

    _roundEngine = GameEngine(
      config: config.boardConfig,
      startingPlayer: startingPlayer,
      evaluator: evaluator,
    );

    _lastAnchor = this.timeSource.now();
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

  /// Suspends the clock anchor (round concluded or paused).
  void _suspendAnchor() {
    _lastAnchor = null;
  }

  /// Applies a chess-clock pulse. Called by the application layer
  /// (`MatchController` ticker) with a measured [delta], or manually in tests;
  /// without a [delta] the pulse is sampled from the monotonic [timeSource].
  void tick([Duration? delta]) {
    if (_state.phase != MatchPhase.inProgress) return;
    if (!_state.isTimerEnabled) return;
    if (_roundResultRecorded) return;

    final now = timeSource.now();
    final elapsed = delta ?? (_lastAnchor != null ? now - _lastAnchor! : Duration.zero);

    // Stale/backward sample guard (only reachable through a non-monotonic
    // test fake): contributes no deduction and must not rewind the anchor,
    // otherwise the next honest sample would re-count processed time.
    if (elapsed <= Duration.zero) return;

    if (_lastAnchor == null || now > _lastAnchor!) {
      _lastAnchor = now;
    }

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
    _suspendAnchor();

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
  /// [timestamp] is a wall-clock stamp recorded on the [Move] for display and
  /// logging ONLY — it never influences remaining chess-clock time. Deduction
  /// of the elapsed slice up to the move instant is measured exclusively from
  /// the monotonic [timeSource] against the internal anchor.
  void makeMove(Position position, {DateTime? timestamp}) {
    if (_state.phase != MatchPhase.inProgress) return;

    // 1. Deduct elapsed time up to the move instant (monotonic source only).
    if (_state.isTimerEnabled) {
      final now = timeSource.now();
      final anchor = _lastAnchor;
      final elapsed = (anchor != null && now > anchor) ? now - anchor : Duration.zero;
      if (anchor == null || now > anchor) {
        _lastAnchor = now;
      }

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

    // 2. Execute board move on inner engine (timestamp is record-only).
    try {
      _roundEngine.makeMove(position, timestamp: timestamp ?? wallClock?.call());
      _state = _state.copyWith(roundState: _roundEngine.state);

      // 3. Check for round conclusion
      if (_roundEngine.isGameOver && !_roundResultRecorded) {
        _roundResultRecorded = true;
        _suspendAnchor();

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
    } catch (e) {
      // Invalid move: the board, scores, and current turn remain unchanged.
      // However, elapsed time up to move reception was deducted and
      // listeners MUST be notified so internal state remains consistent.
      _notifyListeners();
      rethrow;
    }
  }

  /// Advances to the next round, alternating the starting player,
  /// resetting the board and timers, and preserving player scores.
  ///
  /// If the current round was the final round, concludes the match.
  void nextRound() {
    // Guard: advancing is only legal from a concluded round. Repeated or
    // racing invocations (auto-transition overlapping a manual command)
    // become safe no-ops instead of skipping a round or wiping an active board.
    if (_state.phase != MatchPhase.roundEnded) return;

    if (_state.isFinalRound) {
      finalizeMatch();
      return;
    }

    _roundResultRecorded = false;

    final nextRoundNumber = _state.currentRound + 1;
    final nextStarter = _state.roundStartingPlayer.other;

    _roundEngine = GameEngine(
      config: _state.config.boardConfig,
      startingPlayer: nextStarter,
      evaluator: evaluator,
    );

    final resetTime = _state.config.timerConfig.durationPerPlayer;

    _state = _state.copyWith(
      currentRound: nextRoundNumber,
      roundStartingPlayer: nextStarter,
      roundState: _roundEngine.state,
      phase: MatchPhase.inProgress,
      clearRoundResult: true,
      remainingTimeX: resetTime,
      remainingTimeO: resetTime,
    );

    _lastAnchor = timeSource.now();

    _notifyListeners();
  }

  /// Concludes the entire match, calculating the overall match winner or draw.
  void finalizeMatch() {
    if (_state.phase == MatchPhase.matchEnded) return;
    if (_state.phase != MatchPhase.roundEnded || !_state.isFinalRound) {
      return;
    }

    _suspendAnchor();

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

  /// Pauses active gameplay and freezes timers (e.g. user pause or app
  /// backgrounded). The caller (application layer) owns any ticker.
  void pause() {
    if (_state.phase != MatchPhase.inProgress) return;

    if (_state.isTimerEnabled && _lastAnchor != null) {
      // Deduct elapsed slice up to the pause instant (monotonic source).
      final elapsed = timeSource.now() - _lastAnchor!;
      if (elapsed > Duration.zero) {
        final active = _state.currentTurnPlayer;
        if (active == Player.x) {
          final rem = _state.remainingTimeX - elapsed;
          if (rem <= Duration.zero) {
            _state = _state.copyWith(remainingTimeX: Duration.zero);
            _handleTimeout(timedOutPlayer: Player.x);
            return;
          }
          _state = _state.copyWith(remainingTimeX: rem);
        } else {
          final rem = _state.remainingTimeO - elapsed;
          if (rem <= Duration.zero) {
            _state = _state.copyWith(remainingTimeO: Duration.zero);
            _handleTimeout(timedOutPlayer: Player.o);
            return;
          }
          _state = _state.copyWith(remainingTimeO: rem);
        }
      }
    }

    _lastAnchor = null;
    _state = _state.copyWith(phase: MatchPhase.paused);
    _notifyListeners();
  }

  /// Resumes gameplay from paused state. The caller (application layer)
  /// restarts its ticker if desired.
  void resume() {
    if (_state.phase != MatchPhase.paused) return;

    if (_state.isTimerEnabled) {
      final active = _state.currentTurnPlayer;
      final rem = active == Player.x ? _state.remainingTimeX : _state.remainingTimeO;
      if (rem <= Duration.zero) {
        _handleTimeout(timedOutPlayer: active);
        return;
      }
    }

    _lastAnchor = timeSource.now();
    _state = _state.copyWith(phase: MatchPhase.inProgress);
    _notifyListeners();
  }

  /// Resets the current active round's board and clocks,
  /// keeping existing match scores and the starting player of this round intact.
  void resetCurrentRound() {
    _roundResultRecorded = false;

    _roundEngine = GameEngine(
      config: _state.config.boardConfig,
      startingPlayer: _state.roundStartingPlayer,
      evaluator: evaluator,
    );

    final resetTime = _state.config.timerConfig.durationPerPlayer;

    _state = _state.copyWith(
      roundState: _roundEngine.state,
      phase: MatchPhase.inProgress,
      clearRoundResult: true,
      remainingTimeX: resetTime,
      remainingTimeO: resetTime,
    );

    _lastAnchor = timeSource.now();

    _notifyListeners();
  }

  /// Starts a brand new match with reset scores (0 - 0) and round 1.
  void restartMatch({MatchConfig? newConfig}) {
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
    );

    _lastAnchor = timeSource.now();

    _notifyListeners();
  }

  void dispose() {
    _listeners.clear();
  }
}
