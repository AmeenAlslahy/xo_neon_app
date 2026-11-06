import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  group('MatchEngine - Multi-Round Match Lifecycle & Rules', () {
    test('initializes with Round 1, zeroed scores, and Player X as starter', () {
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
      );
      final engine = MatchEngine(config: config, autoStartTimer: false);

      expect(engine.currentRound, 1);
      expect(engine.scoreX, 0);
      expect(engine.scoreO, 0);
      expect(engine.roundStartingPlayer, Player.x);
      expect(engine.currentTurnPlayer, Player.x);
      expect(engine.isRoundOver, false);
      expect(engine.isMatchOver, false);
    });

    test('plays all specified rounds (1, 3, 5) even if mathematically clinched', () {
      // 3-Round match where X wins rounds 1 and 2
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
      );
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Round 1: X wins
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins!
      expect(engine.isRoundOver, true);
      expect(engine.scoreX, 1);
      expect(engine.scoreO, 0);
      expect(engine.isMatchOver, false); // Must NOT end match early!

      // Transition to Round 2
      engine.nextRound();
      expect(engine.currentRound, 2);
      expect(engine.roundStartingPlayer, Player.o); // O starts Round 2!
      expect(engine.currentTurnPlayer, Player.o);
      expect(engine.scoreX, 1); // X keeps score 1
      expect(engine.scoreO, 0); // O keeps score 0

      // Round 2: X wins again (now 2 - 0, X has clinched, but Round 3 MUST still be played!)
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(2, 0)); // O
      engine.makeMove(const Position(0, 2)); // X wins!
      expect(engine.isRoundOver, true);
      expect(engine.scoreX, 2);
      expect(engine.scoreO, 0);
      expect(engine.isMatchOver, false); // Still 1 round left!

      // Transition to Round 3 (Final Round)
      engine.nextRound();
      expect(engine.currentRound, 3);
      expect(engine.roundStartingPlayer, Player.x); // X starts Round 3!
      expect(engine.isFinalRound, true);
      expect(engine.isMatchOver, false);

      // Round 3: O wins
      engine.makeMove(const Position(2, 0)); // X
      engine.makeMove(const Position(0, 0)); // O
      engine.makeMove(const Position(2, 1)); // X
      engine.makeMove(const Position(0, 1)); // O
      engine.makeMove(const Position(1, 0)); // X
      engine.makeMove(const Position(0, 2)); // O wins!
      expect(engine.isRoundOver, true);
      expect(engine.scoreX, 2);
      expect(engine.scoreO, 1);

      // Finalize Match
      engine.finalizeMatch();
      expect(engine.isMatchOver, true);
      expect(engine.matchWinner, Player.x);
      expect(engine.state.isMatchDraw, false);
    });

    test('Player stability: marks and points stay strictly tied to X and O across rounds', () {
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
      );
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Round 1: O wins
      engine.makeMove(const Position(2, 2)); // X
      engine.makeMove(const Position(0, 0)); // O
      engine.makeMove(const Position(1, 1)); // X
      engine.makeMove(const Position(0, 1)); // O
      engine.makeMove(const Position(2, 0)); // X
      engine.makeMove(const Position(0, 2)); // O wins row 0
      expect(engine.scoreX, 0);
      expect(engine.scoreO, 1);

      // Advance to Round 2 (O starts)
      engine.nextRound();
      expect(engine.currentRound, 2);
      expect(engine.roundStartingPlayer, Player.o);
      // Points MUST NOT swap!
      expect(engine.scoreX, 0);
      expect(engine.scoreO, 1);
    });

    test('Final Draw occurs when overall scores are tied after all rounds', () {
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1, // Single round match
      );
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Play a 3x3 draw
      // X O X
      // X O X
      // O X O
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(0, 1)); // O
      engine.makeMove(const Position(0, 2)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(1, 0)); // X
      engine.makeMove(const Position(2, 0)); // O
      engine.makeMove(const Position(1, 2)); // X
      engine.makeMove(const Position(2, 2)); // O
      engine.makeMove(const Position(2, 1)); // X

      expect(engine.isRoundOver, true);
      expect(engine.roundEndReason, RoundEndReason.draw);
      expect(engine.scoreX, 0);
      expect(engine.scoreO, 0);

      engine.finalizeMatch();
      expect(engine.isMatchOver, true);
      expect(engine.matchWinner, isNull);
      expect(engine.state.isMatchDraw, true);
    });

    test('restartMatch resets to Round 1, zeroed scores, and starter X', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 3);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins
      expect(engine.scoreX, 1);

      engine.restartMatch();
      expect(engine.currentRound, 1);
      expect(engine.scoreX, 0);
      expect(engine.scoreO, 0);
      expect(engine.roundStartingPlayer, Player.x);
      expect(engine.isRoundOver, false);
    });
  });

  group('MatchEngine - Chess Clock Timer Mechanics', () {
    test('timer decrements only active player time and transfers clock after valid move', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 60),
          preset: TimerPreset.oneMinute,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      expect(engine.remainingTimeX, const Duration(seconds: 60));
      expect(engine.remainingTimeO, const Duration(seconds: 60));

      // Advance time by 5 seconds while X has turn
      currentTime = currentTime.add(const Duration(seconds: 5));
      engine.tick();
      expect(engine.remainingTimeX, const Duration(seconds: 55));
      expect(engine.remainingTimeO, const Duration(seconds: 60)); // O was untouched!

      // X makes a valid move at second 7
      currentTime = currentTime.add(const Duration(seconds: 2));
      engine.makeMove(const Position(0, 0), timestamp: currentTime);
      expect(engine.remainingTimeX, const Duration(seconds: 53));
      expect(engine.currentTurnPlayer, Player.o); // Now O's turn!

      // Advance time by 4 seconds while O has turn
      currentTime = currentTime.add(const Duration(seconds: 4));
      engine.tick();
      expect(engine.remainingTimeX, const Duration(seconds: 53)); // X untouched
      expect(engine.remainingTimeO, const Duration(seconds: 56)); // O decremented
    });

    test('invalid move does NOT transfer clock or change turn', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 60),
          preset: TimerPreset.oneMinute,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // X plays (0, 0)
      engine.makeMove(const Position(0, 0), timestamp: currentTime);
      expect(engine.currentTurnPlayer, Player.o);

      // O tries to play on occupied cell (0, 0)
      currentTime = currentTime.add(const Duration(seconds: 3));
      expect(
        () => engine.makeMove(const Position(0, 0), timestamp: currentTime),
        throwsA(isA<CellAlreadyOccupiedException>()),
      );
      // Turn MUST still be O's!
      expect(engine.currentTurnPlayer, Player.o);
    });

    test('player running out of time loses round and opponent receives 1 point', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 15),
          preset: TimerPreset.custom,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // Advance time by 16 seconds (exceeding X's 15 seconds)
      currentTime = currentTime.add(const Duration(seconds: 16));
      engine.tick();

      expect(engine.isRoundOver, true);
      expect(engine.roundEndReason, RoundEndReason.timeout);
      expect(engine.roundWinner, Player.o); // Opponent wins!
      expect(engine.scoreX, 0);
      expect(engine.scoreO, 1);
      expect(engine.remainingTimeX, Duration.zero);
    });

    test('pause freezes timer without deducting time; resume continues with exact remaining time', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 30),
          preset: TimerPreset.custom,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // Consume 5s
      currentTime = currentTime.add(const Duration(seconds: 5));
      engine.tick();
      expect(engine.remainingTimeX, const Duration(seconds: 25));

      // Pause match
      engine.pause();
      expect(engine.isPaused, true);

      // Time passes in background (e.g. 100 seconds!)
      currentTime = currentTime.add(const Duration(seconds: 100));
      engine.tick(); // In paused state, ticks are ignored!
      expect(engine.remainingTimeX, const Duration(seconds: 25)); // Untouched!

      // Resume match
      engine.resume();
      expect(engine.isPaused, false);
      expect(engine.remainingTimeX, const Duration(seconds: 25));

      // Another 5 seconds of active play
      currentTime = currentTime.add(const Duration(seconds: 5));
      engine.tick();
      expect(engine.remainingTimeX, const Duration(seconds: 20));
    });

    test('deterministic behavior near timeout expiration', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 10),
          preset: TimerPreset.custom,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // Move arrives at exactly 9.9 seconds (0.1s before timeout): valid move!
      currentTime = currentTime.add(const Duration(milliseconds: 9900));
      engine.makeMove(const Position(0, 0), timestamp: currentTime);
      expect(engine.isRoundOver, false);
      expect(engine.currentTurnPlayer, Player.o);

      // Move arrives at 10.1 seconds after clock expired: triggers timeout!
      currentTime = currentTime.add(const Duration(milliseconds: 10100));
      engine.makeMove(const Position(1, 0), timestamp: currentTime);
      expect(engine.isRoundOver, true);
      expect(engine.roundEndReason, RoundEndReason.timeout);
      expect(engine.roundWinner, Player.x); // O timed out, X wins!
    });
  });

  group('MatchEngine - Baseline Defect Reproduction & Edge Cases', () {
    test('BUG REPRO: roundWinner and roundEndReason MUST be cleared when transitioning to next round', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 3);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Round 1: X wins
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins!

      expect(engine.isRoundOver, true);
      expect(engine.roundWinner, Player.x);
      expect(engine.roundEndReason, RoundEndReason.win);

      // Advance to Round 2
      engine.nextRound();

      expect(engine.currentRound, 2);
      expect(engine.isRoundOver, false);
      // THESE SHOULD BE NULL DURING ACTIVE ROUND 2:
      expect(engine.roundWinner, isNull, reason: 'roundWinner must be cleared in nextRound()');
      expect(engine.roundEndReason, isNull, reason: 'roundEndReason must be cleared in nextRound()');
    });

    test('BUG REPRO: roundWinner and roundEndReason MUST be cleared when resetting round after a win', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 3);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Round 1: X wins
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins!

      expect(engine.isRoundOver, true);
      expect(engine.roundWinner, Player.x);

      // Reset the round
      engine.resetCurrentRound();

      expect(engine.isRoundOver, false);
      expect(engine.roundWinner, isNull, reason: 'roundWinner must be cleared in resetCurrentRound()');
      expect(engine.roundEndReason, isNull, reason: 'roundEndReason must be cleared in resetCurrentRound()');
    });

    test('BUG REPRO: finalizeMatch MUST be rejected if called during an active in-progress round', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 3);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Round 1 is in progress
      expect(engine.phase, MatchPhase.inProgress);
      expect(engine.isRoundOver, false);

      // Calling finalizeMatch prematurely
      engine.finalizeMatch();

      expect(engine.isMatchOver, false, reason: 'finalizeMatch must not end match while round is inProgress');
      expect(engine.phase, MatchPhase.inProgress);
    });

    test('BUG REPRO: invalid move decrements elapsed time and notifies listeners without granting extra time', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 30),
          preset: TimerPreset.custom,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      var notificationCount = 0;
      MatchState? lastNotifiedState;
      engine.addListener((state) {
        notificationCount++;
        lastNotifiedState = state;
      });

      // Valid move by X at t=5s
      currentTime = currentTime.add(const Duration(seconds: 5));
      engine.makeMove(const Position(0, 0), timestamp: currentTime);
      expect(engine.remainingTimeX, const Duration(seconds: 25));
      expect(notificationCount, 1);

      // O attempts an invalid move (cell already occupied) at t=8s (3s later)
      currentTime = currentTime.add(const Duration(seconds: 3));
      expect(
        () => engine.makeMove(const Position(0, 0), timestamp: currentTime),
        throwsA(isA<CellAlreadyOccupiedException>()),
      );

      // O's time MUST be 30s - 3s = 27s
      expect(engine.remainingTimeO, const Duration(seconds: 27));
      // Listener MUST be notified of the updated time!
      expect(notificationCount, 2, reason: 'Listeners must be notified when time updates even on invalid move');
      expect(lastNotifiedState?.remainingTimeO, const Duration(seconds: 27));
      // Turn and board remain unchanged
      expect(engine.currentTurnPlayer, Player.o);
    });

    test('BUG REPRO: calling pause when time has expired triggers timeout rather than pausing with zero time', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 10),
          preset: TimerPreset.custom,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // Time expires: 12 seconds pass (2s past limit) before pause is called
      currentTime = currentTime.add(const Duration(seconds: 12));
      engine.pause();

      expect(engine.isRoundOver, true, reason: 'Expired time at pause instant must trigger round timeout');
      expect(engine.roundEndReason, RoundEndReason.timeout);
      expect(engine.roundWinner, Player.o);
    });

    test('Zero boundary policy: invalid move arriving at exact zero remaining triggers timeout and rejects move', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final config = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: 10),
          preset: TimerPreset.custom,
        ),
      );

      final engine = MatchEngine(
        config: config,
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // X makes a valid move at second 2
      currentTime = currentTime.add(const Duration(seconds: 2));
      engine.makeMove(const Position(0, 0), timestamp: currentTime);
      expect(engine.remainingTimeX, const Duration(seconds: 8));
      expect(engine.currentTurnPlayer, Player.o);

      // O's clock expires: exactly 10 seconds elapse for O, and O attempts an occupied cell
      currentTime = currentTime.add(const Duration(seconds: 10));
      // Remaining for O reaches Duration.zero.
      // Must trigger timeout; invalid move is NOT accepted and no mark placed.
      engine.makeMove(const Position(0, 0), timestamp: currentTime);

      expect(engine.isRoundOver, true);
      expect(engine.roundEndReason, RoundEndReason.timeout);
      expect(engine.roundWinner, Player.x); // O timed out, X wins!
      expect(engine.scoreX, 1);
      expect(engine.scoreO, 0);
      expect(engine.remainingTimeO, Duration.zero);
    });

    test('Score idempotency: moves or ticks after round conclusion NEVER increment points multiple times', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 3);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Round 1: X wins
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins!

      expect(engine.scoreX, 1);
      expect(engine.scoreO, 0);

      // Attempt additional moves on finished round
      engine.makeMove(const Position(2, 2));
      engine.makeMove(const Position(2, 0));
      expect(engine.scoreX, 1, reason: 'Scores must remain exactly 1');
      expect(engine.scoreO, 0);

      // Attempt clock ticks
      engine.tick(const Duration(seconds: 5));
      expect(engine.scoreX, 1);
      expect(engine.scoreO, 0);
    });

    test('Repeated finalizeMatch calls are safe no-ops and preserve final winner and scores', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 1);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Win round 1
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins!

      expect(engine.isRoundOver, true);
      engine.finalizeMatch();

      expect(engine.isMatchOver, true);
      expect(engine.matchWinner, Player.x);

      // Repeated calls must be safe no-ops
      engine.finalizeMatch();
      engine.finalizeMatch();
      expect(engine.isMatchOver, true);
      expect(engine.matchWinner, Player.x);
      expect(engine.scoreX, 1);
      expect(engine.scoreO, 0);
    });
  });

  group('MatchEngine - Stale Timestamps & Clock-Jump Policy', () {
    MatchConfig tenSecondClockConfig() => MatchConfig(
          boardConfig: BoardConfig.grid3x3,
          totalRounds: 1,
          timerConfig: const TimerConfig(
            enabled: true,
            durationPerPlayer: Duration(seconds: 10),
            preset: TimerPreset.custom,
          ),
        );

    test('REPRO: stale move timestamp grants no refund and no cross-period double-deduction', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final engine = MatchEngine(
        config: tenSecondClockConfig(),
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // 6s elapse during X's turn: X has 4s left, anchor at T+6s
      currentTime = currentTime.add(const Duration(seconds: 6));
      engine.tick();
      expect(engine.remainingTimeX, const Duration(seconds: 4));

      // X moves with a STALE timestamp (T+2s, older than the anchor T+6s)
      engine.makeMove(
        const Position(0, 0),
        timestamp: currentTime.subtract(const Duration(seconds: 4)),
      );

      // MUST NOT refund: X keeps exactly 4s (pre-fix it jumped to 8s)
      expect(engine.remainingTimeX, const Duration(seconds: 4),
          reason: 'A stale timestamp must never increase any player balance');
      expect(engine.currentTurnPlayer, Player.o);

      // O's honest move at T+7s: only 1s deducted (period T6->T7). The
      // already-processed period T2..T6 must not be re-counted against O.
      currentTime = currentTime.add(const Duration(seconds: 1));
      engine.makeMove(const Position(1, 0), timestamp: currentTime);
      expect(engine.remainingTimeO, const Duration(seconds: 9),
          reason: 'The period already processed under X (T2..T6) must not be re-counted against O');

      // X's honest move at T+9s: 2s deducted from X (period T7->T9)
      currentTime = currentTime.add(const Duration(seconds: 2));
      engine.makeMove(const Position(0, 1), timestamp: currentTime);
      expect(engine.remainingTimeX, const Duration(seconds: 2));

      // Real time reaches T+12 on O's turn: only the honest 3s (T9->T12)
      currentTime = currentTime.add(const Duration(seconds: 3));
      engine.tick();
      expect(engine.remainingTimeO, const Duration(seconds: 6));
      expect(engine.isRoundOver, false,
          reason: 'No false timeout may arise from the earlier stale sample');
    });

    test('REPRO: backward clock sample at tick does not rewind the anchor or force a false timeout', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final engine = MatchEngine(
        config: tenSecondClockConfig(),
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // T+6: honest tick, X has 4s left, anchor at T+6s
      currentTime = currentTime.add(const Duration(seconds: 6));
      engine.tick();
      expect(engine.remainingTimeX, const Duration(seconds: 4));

      // System clock jumps backward to T+2 (e.g. NTP correction): stale sample
      currentTime = currentTime.subtract(const Duration(seconds: 4));
      engine.tick();
      // No deduction and the anchor must stay at T+6s
      expect(engine.remainingTimeX, const Duration(seconds: 4));

      // Real clock continues to T+9: only the honest 3s (T6->T9) deducted
      currentTime = currentTime.add(const Duration(seconds: 7));
      engine.tick();
      expect(engine.remainingTimeX, const Duration(seconds: 1),
          reason: 'Anchor must not rewind; pre-fix it re-counted T2..T9 (7s) and forced a false timeout');
      expect(engine.isRoundOver, false);
    });

    test('a move stamped at or before expiry cannot resurrect a detected timeout', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final engine = MatchEngine(
        config: tenSecondClockConfig(),
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // X moves at T+2s (anchor T+2s)
      engine.makeMove(const Position(0, 0), timestamp: currentTime.add(const Duration(seconds: 2)));

      // O's clock detected expired at T+12s
      currentTime = currentTime.add(const Duration(seconds: 12));
      engine.tick();
      expect(engine.isRoundOver, true);
      expect(engine.roundEndReason, RoundEndReason.timeout);
      expect(engine.roundWinner, Player.x);
      expect(engine.scoreX, 1);

      // A late move with a stale stamp must be rejected, not resurrect the round
      engine.makeMove(const Position(2, 2), timestamp: currentTime.subtract(const Duration(seconds: 7)));
      expect(engine.isRoundOver, true);
      expect(engine.roundEndReason, RoundEndReason.timeout);
      expect(engine.scoreX, 1);
      expect(engine.state.roundState.moveHistory.length, 1,
          reason: 'No new move may be recorded after the detected timeout');
    });

    test('invalid move with stale timestamp keeps turn and balances untouched', () {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final engine = MatchEngine(
        config: tenSecondClockConfig(),
        clock: () => currentTime,
        autoStartTimer: false,
      );

      // X moves at T+2s (anchor T+2s, X rem 8s, O's turn)
      engine.makeMove(const Position(0, 0), timestamp: currentTime.add(const Duration(seconds: 2)));

      // O attempts an occupied cell with a stale stamp (T+1s)
      expect(
        () => engine.makeMove(
          const Position(0, 0),
          timestamp: currentTime.add(const Duration(seconds: 1)),
        ),
        throwsA(isA<CellAlreadyOccupiedException>()),
      );

      // Turn unchanged; NO balance may increase from the stale sample
      expect(engine.currentTurnPlayer, Player.o);
      expect(engine.remainingTimeO, const Duration(seconds: 10),
          reason: 'Pre-fix the negative elapsed refunded O to 11s');
      expect(engine.remainingTimeX, const Duration(seconds: 8));
    });
  });

  group('MatchEngine - nextRound Invocation Safety', () {
    test('REPRO: repeated nextRound calls (manual tap racing banner auto-fire) advance exactly one round', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 3);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      // Round 1: X wins
      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins
      expect(engine.phase, MatchPhase.roundEnded);

      // First transition: legal and correct
      engine.nextRound();
      expect(engine.currentRound, 2);
      expect(engine.roundStartingPlayer, Player.o);
      expect(engine.phase, MatchPhase.inProgress);

      // Second immediate call (countdown callback racing a manual tap):
      // MUST be a safe no-op, not a skip to round 3
      engine.nextRound();
      expect(engine.currentRound, 2,
          reason: 'nextRound from a non-roundEnded phase must not skip a round');
      expect(engine.roundStartingPlayer, Player.o);
      expect(engine.phase, MatchPhase.inProgress);
      expect(engine.state.roundState.moveHistory, isEmpty);
      expect(engine.scoreX, 1, reason: 'Scores preserved across the no-op call');
      expect(engine.scoreO, 0);
    });

    test('REPRO: nextRound called mid-round is rejected (no board wipe or round skip)', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 3);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O — round 1 in progress

      engine.nextRound();

      expect(engine.currentRound, 1,
          reason: 'Advancing from an active round must be rejected');
      expect(engine.phase, MatchPhase.inProgress);
      expect(engine.state.roundState.moveHistory.length, 2,
          reason: 'The active round board must remain untouched');
    });

    test('nextRound on the concluded final round still finalizes the match', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 1);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins the single (final) round

      engine.nextRound(); // legal: phase is roundEnded on the final round

      expect(engine.isMatchOver, true);
      expect(engine.matchWinner, Player.x);
    });
  });

  group('MatchEngine - Concluded Round State Invariants', () {
    test('no-op API calls during a concluded final round preserve the exact state object', () {
      final config = MatchConfig(boardConfig: BoardConfig.grid3x3, totalRounds: 1);
      final engine = MatchEngine(config: config, autoStartTimer: false);

      engine.makeMove(const Position(0, 0)); // X
      engine.makeMove(const Position(1, 0)); // O
      engine.makeMove(const Position(0, 1)); // X
      engine.makeMove(const Position(1, 1)); // O
      engine.makeMove(const Position(0, 2)); // X wins the final round

      final snapshot = engine.state;
      expect(engine.phase, MatchPhase.roundEnded);
      expect(engine.isFinalRound, true);
      expect(engine.isMatchOver, false);

      // Every public call that must be a no-op in this phase:
      engine.pause();
      engine.resume();
      engine.tick(const Duration(seconds: 5));
      engine.makeMove(const Position(2, 2));

      expect(identical(engine.state, snapshot), isTrue,
          reason: 'No-op calls must not churn the concluded-round state object');
      expect(engine.phase, MatchPhase.roundEnded);
      expect(engine.scoreX, 1);
      expect(engine.scoreO, 0);
    });
  });
}
