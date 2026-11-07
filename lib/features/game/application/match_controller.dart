import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/xo_engine.dart';
import 'match_providers.dart';

/// Immutable UI-facing snapshot exposed by [matchControllerProvider]: the
/// authoritative [MatchState] plus the controller-owned transition countdown.
class MatchUiState {
  final MatchState match;
  final int roundTransitionSecondsRemaining;
  final bool isRoundTransitionRunning;

  /// True while background-freeze holds the transition countdown (and any
  /// scheduling) until an explicit manual resume.
  final bool isSchedulingPaused;

  const MatchUiState({
    required this.match,
    required this.roundTransitionSecondsRemaining,
    required this.isRoundTransitionRunning,
    required this.isSchedulingPaused,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchUiState &&
          other.match == match &&
          other.roundTransitionSecondsRemaining == roundTransitionSecondsRemaining &&
          other.isRoundTransitionRunning == isRoundTransitionRunning &&
          other.isSchedulingPaused == isSchedulingPaused;

  @override
  int get hashCode => Object.hash(
        match,
        roundTransitionSecondsRemaining,
        isRoundTransitionRunning,
        isSchedulingPaused,
      );
}

/// Application-layer owner of ALL match timing and transition pacing,
/// exposed to the UI through Riverpod as [matchControllerProvider].
///
/// [MatchEngine] is a pure rules/state machine: it schedules nothing. This
/// notifier is the only component allowed to schedule timers against a match:
/// - the chess-clock ticker (100 ms) feeding [MatchEngine.tick] deltas,
/// - the 3s (2s reduced-motion) auto-advance countdown between non-final
///   rounds,
/// - the 1.2s (0.4s reduced-motion) finalize delay before the final result.
///
/// The UI watches [matchControllerProvider] and stays passive: it renders the
/// snapshot and forwards user intent to the command methods below.
class MatchController extends Notifier<MatchUiState> {
  static const Duration _tickerInterval = Duration(milliseconds: 100);

  late MatchEngine _engine;
  late TimeSource _timeSource;

  /// Mirrors the accessibility setting; affects transition pacing only.
  bool reduceMotion = false;

  Timer? _ticker;
  Duration _lastPulse = Duration.zero;

  Timer? _transitionTimer;
  int _transitionSecondsRemaining = 0;
  bool _hasLiveTransition = false;

  /// Background-freeze flag: while true, the transition countdown timer is
  /// canceled but its remaining seconds are preserved until a manual resume.
  bool _schedulingPaused = false;

  Timer? _finalizeTimer;

  /// True when the app backgrounded during the final-result presentation
  /// delay: the delay timer is frozen and the result is presented
  /// immediately when the app returns ([onAppResumed]) — no manual resume
  /// required, per the adopted final-result policy.
  bool _resultPendingOnReturn = false;

  @override
  MatchUiState build() {
    final config = ref.watch(matchConfigProvider);
    _timeSource = ref.watch(timeSourceProvider);
    _engine = MatchEngine(
      config: config,
      timeSource: _timeSource,
    );
    _engine.addListener(_onEngineStateChanged);
    ref.onDispose(_teardown);
    _lastPulse = _timeSource.now();
    if (config.timerConfig.enabled) {
      _startTicker();
    }
    return _snapshot();
  }

  void _teardown() {
    _ticker?.cancel();
    _ticker = null;
    _cancelTransitions();
    _schedulingPaused = false;
    _resultPendingOnReturn = false;
    _engine.removeListener(_onEngineStateChanged);
    _engine.dispose();
  }

  MatchUiState _snapshot() => MatchUiState(
        match: _engine.state,
        roundTransitionSecondsRemaining: _transitionSecondsRemaining,
        isRoundTransitionRunning: _hasLiveTransition,
        isSchedulingPaused: _schedulingPaused,
      );

  void _commit() => state = _snapshot();

  // ---- Read-facing getters (delegate to the engine) -----------------------

  MatchConfig get config => _engine.config;
  int get currentRound => _engine.currentRound;
  int get scoreX => _engine.scoreX;
  int get scoreO => _engine.scoreO;
  Player get roundStartingPlayer => _engine.roundStartingPlayer;
  Player get currentTurnPlayer => _engine.currentTurnPlayer;
  MatchPhase get phase => _engine.phase;
  RoundEndReason? get roundEndReason => _engine.roundEndReason;
  Player? get roundWinner => _engine.roundWinner;
  Player? get matchWinner => _engine.matchWinner;
  Duration get remainingTimeX => _engine.remainingTimeX;
  Duration get remainingTimeO => _engine.remainingTimeO;
  bool get isRoundOver => _engine.isRoundOver;
  bool get isMatchOver => _engine.isMatchOver;
  bool get isFinalRound => _engine.isFinalRound;
  bool get isPaused => _engine.isPaused;

  /// The current UI-facing snapshot (Riverpod's [Notifier.state] is protected,
  /// so external callers read through this getter).
  MatchUiState get snapshot => state;

  /// Seconds left on the auto-advance countdown between non-final rounds
  /// (display-only; 0 when no transition is scheduled).
  int get roundTransitionSecondsRemaining => _transitionSecondsRemaining;
  bool get isRoundTransitionRunning => _hasLiveTransition;

  // ---- Commands -----------------------------------------------------------

  /// Starts (or restarts) a fresh match, optionally with a new configuration.
  /// An explicit user action, so a background freeze ends here.
  void startMatch({MatchConfig? config}) {
    _cancelTransitions();
    _schedulingPaused = false;
    _engine.restartMatch(newConfig: config);
    _syncClock();
    _commit();
  }

  /// Applies a move through the engine (rules). The engine deducts the
  /// elapsed slice from its monotonic source up to this instant.
  void makeMove(Position position) => _engine.makeMove(position);

  /// Pauses the match and stops the chess-clock ticker (user action or app
  /// lifecycle). Approved background policy: the transition countdown is also
  /// frozen, preserving its remaining seconds for a manual [resume] — nothing
  /// auto-resumes and background time is never counted.
  ///
  /// When [freezeResultPresentation] is true (app background), a pending
  /// final-result presentation is frozen as well; it completes automatically
  /// when [onAppResumed] fires on return. A foreground pause never freezes
  /// the presentation: the delay keeps its current behavior.
  void pause({bool freezeResultPresentation = false}) {
    _stopTicker();
    _engine.pause();
    if (_transitionTimer != null) {
      // Freeze the countdown: cancel the timer, keep the remaining seconds.
      _transitionTimer?.cancel();
      _transitionTimer = null;
      _hasLiveTransition = false;
      _schedulingPaused = true;
    }
    if (freezeResultPresentation && _finalizeTimer != null) {
      _finalizeTimer?.cancel();
      _finalizeTimer = null;
      _resultPendingOnReturn = true;
    }
    _commit();
  }

  /// Resumes the match (explicit manual action only — the lifecycle observer
  /// never calls this) and restarts the chess-clock ticker. A frozen
  /// transition countdown completes from its remaining seconds.
  void resume() {
    _engine.resume();
    if (_schedulingPaused) {
      _schedulingPaused = false;
      _unfreezeTransitionCountdown();
    }
    _syncClock();
    _commit();
  }

  /// Called when the app returns to the foreground. Presents a background-
  /// frozen final result immediately — no manual resume required, per the
  /// adopted final-result policy. Does NOT touch the transition countdown:
  /// that stays frozen until a manual resume.
  void onAppResumed() {
    if (_resultPendingOnReturn) {
      _resultPendingOnReturn = false;
      _completeResultPresentation();
    }
    _commit();
  }

  /// Completes a pending final-result presentation, guarded against stale
  /// results (a round reset or match restart meanwhile drops it).
  void _completeResultPresentation() {
    if (_engine.phase == MatchPhase.roundEnded &&
        _engine.isFinalRound &&
        !_engine.isMatchOver) {
      _engine.finalizeMatch();
    }
  }

  /// Advances to the next round (manual skip or the auto-transition itself).
  /// Cancels any pending transition scheduling first.
  void nextRound() {
    _cancelTransitions();
    _schedulingPaused = false;
    _engine.nextRound();
    _syncClock();
    _commit();
  }

  /// Resets the current active round (replay). Cancels any pending
  /// transition scheduling: the result it was scheduled for no longer exists.
  /// An explicit user action, so a background freeze ends here and the fresh
  /// round runs normally.
  void resetCurrentRound() {
    _cancelTransitions();
    _schedulingPaused = false;
    _engine.resetCurrentRound();
    _syncClock();
    _commit();
  }

  // ---- Internal scheduling ------------------------------------------------

  void _onEngineStateChanged(MatchState next) {
    // The round a pending transition was scheduled for no longer exists:
    // a round reset, restart, or advancement moved the phase back to an
    // active round. Cancel the stale scheduling operation.
    if (next.phase == MatchPhase.inProgress) {
      _cancelTransitions();
    }

    // The match is over: the chess clock must not continue.
    if (next.isMatchOver) {
      _stopTicker();
    }

    if (next.isRoundOver && !next.isMatchOver) {
      if (next.isFinalRound) {
        _scheduleFinalize();
      } else {
        _scheduleRoundTransition();
      }
    }

    _commit();
  }

  /// Keeps the ticker running exactly while an active round has a chess clock.
  void _syncClock() {
    _lastPulse = _timeSource.now();
    final shouldRun = _engine.phase == MatchPhase.inProgress &&
        _engine.config.timerConfig.enabled &&
        !_engine.isRoundOver;
    if (shouldRun) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _lastPulse = _timeSource.now();
    _ticker = Timer.periodic(_tickerInterval, (_) {
      final now = _timeSource.now();
      final delta = now - _lastPulse;
      _lastPulse = now;
      if (delta > Duration.zero) {
        _engine.tick(delta);
      }
      // State notifications flow from the engine listener via _commit().
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _scheduleRoundTransition() {
    _cancelTransitions();
    _hasLiveTransition = true;
    _transitionSecondsRemaining = reduceMotion ? 2 : 3;
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_transitionSecondsRemaining <= 1) {
        _cancelTransitions();
        nextRound();
        return;
      }
      _transitionSecondsRemaining--;
      _commit();
    });
  }

  void _scheduleFinalize() {
    _cancelTransitions();
    _finalizeTimer = Timer(
      reduceMotion
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 1200),
      () {
        _finalizeTimer = null;
        // Defense-in-depth result guard: finalize only if the engine still
        // holds the concluded final round. A reset would already have
        // canceled this timer via the inProgress notification.
        if (_engine.phase == MatchPhase.roundEnded &&
            _engine.isFinalRound &&
            !_engine.isMatchOver) {
          _engine.finalizeMatch();
        }
      },
    );
  }

  void _cancelTransitions() {
    _transitionTimer?.cancel();
    _transitionTimer = null;
    _finalizeTimer?.cancel();
    _finalizeTimer = null;
    _hasLiveTransition = false;
    _transitionSecondsRemaining = 0;
    // Any pending result presentation belongs to a scheduling that no longer
    // exists once transitions are canceled (reset / restart / advancement).
    _resultPendingOnReturn = false;
  }

  /// Restarts the transition countdown from its preserved remaining seconds
  /// after a background freeze. Drops the scheduling entirely if its round no
  /// longer exists (stale-guard: reset, restart, or advancement meanwhile).
  void _unfreezeTransitionCountdown() {
    _transitionTimer?.cancel();
    _transitionTimer = null;
    final state = _engine.state;
    if (_transitionSecondsRemaining <= 0 ||
        !state.isRoundOver ||
        state.isMatchOver ||
        state.isFinalRound) {
      _hasLiveTransition = false;
      _transitionSecondsRemaining = 0;
      return;
    }
    _hasLiveTransition = true;
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_transitionSecondsRemaining <= 1) {
        _cancelTransitions();
        nextRound();
        return;
      }
      _transitionSecondsRemaining--;
      _commit();
    });
  }
}
