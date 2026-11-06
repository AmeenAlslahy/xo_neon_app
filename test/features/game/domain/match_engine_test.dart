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
}
