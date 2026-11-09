import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/l10n/locale_providers.dart';
import 'fake_system_move_port.dart';
import 'package:xo_neon_app/features/game/application/match_controller.dart';
import 'package:xo_neon_app/features/game/application/match_providers.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  MatchConfig config({
    int rounds = 3,
    bool timer = false,
    bool vsSystem = false,
    Player human = Player.x,
  }) =>
      MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: rounds,
        timerConfig: timer
            ? const TimerConfig(
                enabled: true,
                durationPerPlayer: Duration(seconds: 30),
                preset: TimerPreset.custom,
              )
            : const TimerConfig.disabled(),
        vsSystem: vsSystem,
        humanPlayer: human,
      );

  /// Creates a ProviderContainer with the given configuration, a
  /// deterministic FakeTimeSource, and a controllable system-move port. By
  /// default the configuration provider is overridden and the controller kept
  /// alive for the whole test; tests that exercise the real fallback or the
  /// disposal lifecycle disable those.
  (ProviderContainer, MatchController) buildContainer({
    MatchConfig? matchConfig,
    FakeTimeSource? timeSource,
    bool overrideConfig = true,
    bool keepAlive = true,
    FakeSystemMovePort? movePort,
    Duration systemThinkingDelay = Duration.zero,
  }) {
    final time = timeSource ?? FakeTimeSource();
    final container = ProviderContainer(
      overrides: [
        if (overrideConfig)
          matchConfigProvider.overrideWithValue(matchConfig ?? config()),
        timeSourceProvider.overrideWithValue(time),
        systemMovePortProvider.overrideWithValue(
            movePort ?? FakeSystemMovePort()),
        systemThinkingDelayProvider.overrideWithValue(systemThinkingDelay),
      ],
    );
    final controller = container.read(matchControllerProvider.notifier);
    if (keepAlive) {
      // Keep the auto-disposable provider alive for the whole test.
      container.listen(matchControllerProvider, (_, _) {});
    }
    return (container, controller);
  }

  /// Wins one round for X through the controller. When [xStarts] is false,
  /// O opens the round and X still wins.
  void winRoundForX(MatchController controller, {required bool xStarts}) {
    if (xStarts) {
      controller.makeMove(const Position(0, 0)); // X
      controller.makeMove(const Position(1, 0)); // O
      controller.makeMove(const Position(0, 1)); // X
      controller.makeMove(const Position(1, 1)); // O
      controller.makeMove(const Position(0, 2)); // X wins
    } else {
      controller.makeMove(const Position(1, 0)); // O
      controller.makeMove(const Position(0, 0)); // X
      controller.makeMove(const Position(1, 1)); // O
      controller.makeMove(const Position(0, 1)); // X
      controller.makeMove(const Position(2, 0)); // O
      controller.makeMove(const Position(0, 2)); // X wins
    }
  }

  group('MatchController - Automatic Round Transition', () {
    test('auto-advances to the next round after the 3s countdown, without any UI timer', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        expect(controller.isRoundOver, true);
        expect(controller.isFinalRound, false);
        expect(controller.roundTransitionSecondsRemaining, 3,
            reason: 'Controller schedules the transition countdown');

        async.elapse(const Duration(seconds: 1));
        expect(controller.roundTransitionSecondsRemaining, 2);
        expect(controller.currentRound, 1, reason: 'Not yet advanced');

        async.elapse(const Duration(seconds: 1));
        expect(controller.roundTransitionSecondsRemaining, 1);

        async.elapse(const Duration(seconds: 1));
        expect(controller.currentRound, 2, reason: 'Auto-advanced by the controller');
        expect(controller.roundStartingPlayer, Player.o);
        expect(controller.isRoundOver, false);
        expect(controller.roundTransitionSecondsRemaining, 0);
      });
    });

    test('reduced motion shortens the countdown to 2 seconds', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);
        controller.reduceMotion = true;

        winRoundForX(controller, xStarts: true);
        expect(controller.roundTransitionSecondsRemaining, 2);

        async.elapse(const Duration(seconds: 1));
        expect(controller.roundTransitionSecondsRemaining, 1);

        async.elapse(const Duration(seconds: 1));
        expect(controller.currentRound, 2);
      });
    });

    test('resetting the round cancels the pending auto-transition', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        controller.resetCurrentRound();
        expect(controller.isRoundOver, false);

        async.elapse(const Duration(seconds: 5));
        expect(controller.currentRound, 1,
            reason: 'The stale transition scheduling must be canceled by the reset');
        expect(controller.isRoundOver, false);
        expect(controller.roundTransitionSecondsRemaining, 0);
      });
    });

    test('a newer round conclusion supersedes an older finalize scheduling', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer(matchConfig: config(rounds: 1));
        addTearDown(container.dispose);

        // Final (single) round won: finalize scheduled at t=0 (due t=1200ms).
        winRoundForX(controller, xStarts: true);
        expect(controller.isFinalRound, true);

        async.elapse(const Duration(milliseconds: 400));
        // Player resets the round, then quickly re-wins it.
        controller.resetCurrentRound();
        winRoundForX(controller, xStarts: true);

        // At t=1200ms the OLD delay would have fired: it must be inert.
        async.elapse(const Duration(milliseconds: 800));
        expect(controller.isMatchOver, false,
            reason: 'The stale finalize scheduling must be canceled by the reset');

        // The NEW delay (scheduled at t=400, due t=1600) concludes the match.
        async.elapse(const Duration(milliseconds: 500));
        expect(controller.isMatchOver, true);
        expect(controller.matchWinner, Player.x);
        expect(controller.scoreX, 2);
      });
    });
  });

  group('MatchController - Finalize Delay', () {
    test('the final round concludes automatically after the 1.2s delay', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer(matchConfig: config(rounds: 1));
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        expect(controller.isRoundOver, true);
        expect(controller.isMatchOver, false);

        async.elapse(const Duration(milliseconds: 1300));
        expect(controller.isMatchOver, true);
        expect(controller.matchWinner, Player.x);
      });
    });
  });

  group('MatchController - Chess-Clock Ticker Ownership', () {
    test('ticker feeds engine deltas so clocks advance without manual ticks', () {
      fakeAsync((async) {
        final time = FakeTimeSource();
        final (container, controller) = buildContainer(
          matchConfig: config(timer: true),
          timeSource: time,
        );
        addTearDown(container.dispose);

        expect(controller.remainingTimeX, const Duration(seconds: 30));

        // One wall-clock second: the ticker deducts it from X's clock.
        time.advance(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 1));
        expect(controller.remainingTimeX, const Duration(seconds: 25));
        expect(controller.remainingTimeO, const Duration(seconds: 30),
            reason: 'O is untouched while X holds the turn');
      });
    });

    test('pause issued on app lifecycle freezes the chess clock until resume', () {
      fakeAsync((async) {
        final time = FakeTimeSource();
        final (container, controller) = buildContainer(
          matchConfig: config(timer: true),
          timeSource: time,
        );
        addTearDown(container.dispose);

        time.advance(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 1));
        expect(controller.remainingTimeX, const Duration(seconds: 25));

        // The screen issues this exact command when the app is backgrounded.
        controller.pause();
        expect(controller.isPaused, true);

        // 100 seconds pass in the background: nothing may be deducted.
        time.advance(const Duration(seconds: 100));
        async.elapse(const Duration(seconds: 2));
        expect(controller.remainingTimeX, const Duration(seconds: 25));

        controller.resume();
        expect(controller.isPaused, false);
        expect(controller.remainingTimeX, const Duration(seconds: 25));

        time.advance(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 1));
        expect(controller.remainingTimeX, const Duration(seconds: 20));
      });
    });
  });

  group('MatchController - Cancellation & Disposal', () {
    test('leaving the screen (dispose) cancels all pending transitions', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();

        winRoundForX(controller, xStarts: true);
        expect(controller.roundTransitionSecondsRemaining, 3);

        // Simulates the provider being disposed when the screen unmounts.
        container.dispose();

        async.elapse(const Duration(seconds: 10));
        expect(controller.currentRound, 1,
            reason: 'No transition may run after disposal');
        expect(controller.isRoundOver, true,
            reason: 'State must remain frozen at the concluded round');
      });
    });

    test('startMatch resets scores, round, and starter, and clears transitions', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        controller.startMatch();

        expect(controller.currentRound, 1);
        expect(controller.scoreX, 0);
        expect(controller.scoreO, 0);
        expect(controller.roundStartingPlayer, Player.x);
        expect(controller.isRoundOver, false);
        expect(controller.roundTransitionSecondsRemaining, 0);

        async.elapse(const Duration(seconds: 5));
        expect(controller.currentRound, 1, reason: 'No stale auto-advance after restart');
      });
    });
  });

  group('MatchController - Defaults & Configuration Flow', () {
    test('REPRO: a match started WITHOUT an explicit config uses the approved defaults (3 rounds, timer off)', () {
      final (container, controller) = buildContainer(overrideConfig: false);
      addTearDown(container.dispose);

      final resolved = container.read(matchConfigProvider);
      expect(resolved.totalRounds, 3, reason: 'Approved default: 3 rounds');
      expect(resolved.timerConfig.enabled, false, reason: 'Approved default: chess clock off');
      expect(resolved.boardConfig, BoardConfig.grid3x3);
      expect(controller.config.totalRounds, 3);
      expect(controller.config.timerConfig.enabled, false);
      expect(controller.currentRound, 1);
      expect(controller.isRoundOver, false);
    });

    test('REPRO: explicit user selection flows through pendingMatchConfigProvider', () {
      final time = FakeTimeSource();
      final container = ProviderContainer(
        overrides: [timeSourceProvider.overrideWithValue(time)],
      );
      addTearDown(container.dispose);

      final selected = MatchConfig(
        boardConfig: BoardConfig.grid6x6,
        totalRounds: 5,
      );

      // Production flow: the setup screen publishes the selection BEFORE the
      // board screen mounts and watches the controller.
      container.read(pendingMatchConfigProvider.notifier).select(selected);
      expect(container.read(matchConfigProvider), same(selected));

      final controller = container.read(matchControllerProvider.notifier);
      expect(controller.config, same(selected));
      expect(controller.config.totalRounds, 5);
      expect(controller.config.boardConfig, BoardConfig.grid6x6);
      expect(controller.currentRound, 1);
    });
  });

  group('MatchController - MatchUiState Snapshot', () {
    test('REPRO: the watched snapshot reflects the transition countdown, not engine getters alone', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);

        var ui = container.read(matchControllerProvider);
        expect(ui.isRoundTransitionRunning, true);
        expect(ui.roundTransitionSecondsRemaining, 3);
        expect(ui.match.isRoundOver, true);
        expect(ui.match.isFinalRound, false);
        expect(ui.match.currentRound, 1);

        async.elapse(const Duration(seconds: 1));
        ui = container.read(matchControllerProvider);
        expect(ui.roundTransitionSecondsRemaining, 2);
        expect(ui.isRoundTransitionRunning, true);

        async.elapse(const Duration(seconds: 2));
        ui = container.read(matchControllerProvider);
        expect(ui.roundTransitionSecondsRemaining, 0);
        expect(ui.isRoundTransitionRunning, false);
        expect(ui.match.currentRound, 2, reason: 'Snapshot carries the advanced match');
        expect(ui.match.roundStartingPlayer, Player.o);
      });
    });
  });

  group('MatchController - Provider Lifecycle', () {
    test('closing the last listener auto-disposes the controller and cancels pending transitions', () {
      fakeAsync((async) {
        final time = FakeTimeSource();
        final container = ProviderContainer(
          overrides: [
            matchConfigProvider.overrideWithValue(config()),
            timeSourceProvider.overrideWithValue(time),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(matchControllerProvider.notifier);
        winRoundForX(controller, xStarts: true);
        expect(controller.roundTransitionSecondsRemaining, 3);

        // The screen unmounts: its watch subscription closes.
        final sub = container.listen(matchControllerProvider, (_, _) {});
        sub.close();

        async.elapse(const Duration(seconds: 5));
        expect(controller.currentRound, 1,
            reason: 'Auto-dispose must cancel the stale transition scheduling');
        expect(controller.isRoundOver, true);
      });
    });
  });

  group('MatchController - Language Change Safety', () {
    test('REPRO: toggling the language mid-match never recreates or resets the match', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        // Match in progress with moves on the board.
        controller.makeMove(const Position(0, 0)); // X
        controller.makeMove(const Position(1, 0)); // O
        final matchBefore = controller.snapshot.match;
        final boardBefore = matchBefore.roundState.board;
        final notifierBefore = container.read(matchControllerProvider.notifier);

        // Sanity: the toggle really changed locale-derived strings.
        expect(container.read(stringsProvider).appTitle, 'XO نيون');
        container.read(localeProvider.notifier).toggle();
        expect(container.read(stringsProvider).appTitle, 'XO Neon');

        // The match must be untouched: same state object, same controller.
        expect(identical(controller.snapshot.match, matchBefore), isTrue,
            reason: 'Language change must not rebuild the match state');
        expect(boardBefore.cellAt(const Position(0, 0)), Player.x);
        expect(boardBefore.cellAt(const Position(1, 0)), Player.o);
        expect(controller.currentRound, 1);
        expect(identical(container.read(matchControllerProvider.notifier), notifierBefore),
            isTrue,
            reason: 'Controller instance must survive locale changes');
      });
    });
  });

  group('MatchController - Background Policy', () {
    test('REPRO: transition countdown freezes in the background and never advances during background time', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        var ui = container.read(matchControllerProvider);
        expect(ui.roundTransitionSecondsRemaining, 3);
        expect(ui.isSchedulingPaused, false);

        // App enters the background (the screen issues this exact command).
        controller.pause();
        ui = container.read(matchControllerProvider);
        expect(ui.isSchedulingPaused, true);
        expect(ui.roundTransitionSecondsRemaining, 3,
            reason: 'Remaining seconds preserved at freeze instant');
        expect(ui.isRoundTransitionRunning, false, reason: 'Timer canceled while frozen');

        // 30 seconds of background time: nothing may advance.
        async.elapse(const Duration(seconds: 30));
        ui = container.read(matchControllerProvider);
        expect(ui.roundTransitionSecondsRemaining, 3,
            reason: 'Frozen countdown ignores background time');
        expect(ui.match.currentRound, 1, reason: 'No auto-transition in the background');
        expect(ui.isSchedulingPaused, true, reason: 'No auto-resume');
      });
    });

    test('manual resume completes the remaining countdown and transitions exactly once', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        controller.pause(); // freeze at 3s remaining

        // Explicit manual resume (no auto-resume happens anywhere).
        controller.resume();
        var ui = container.read(matchControllerProvider);
        expect(ui.isSchedulingPaused, false);
        expect(ui.roundTransitionSecondsRemaining, 3);
        expect(ui.isRoundTransitionRunning, true);

        async.elapse(const Duration(seconds: 1));
        ui = container.read(matchControllerProvider);
        expect(ui.roundTransitionSecondsRemaining, 2);
        async.elapse(const Duration(seconds: 1));
        ui = container.read(matchControllerProvider);
        expect(ui.roundTransitionSecondsRemaining, 1);
        async.elapse(const Duration(seconds: 1));
        ui = container.read(matchControllerProvider);
        expect(ui.match.currentRound, 2, reason: 'Exactly one transition');
        expect(ui.match.roundStartingPlayer, Player.o);
        expect(ui.roundTransitionSecondsRemaining, 0);
        expect(ui.isSchedulingPaused, false);

        // No duplicate transition afterwards.
        async.elapse(const Duration(seconds: 5));
        ui = container.read(matchControllerProvider);
        expect(ui.match.currentRound, 2);
        expect(ui.isRoundTransitionRunning, false);
      });
    });

    test('freezing near expiry completes a single transition on the first tick after resume', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        async.elapse(const Duration(seconds: 2));
        expect(container.read(matchControllerProvider).roundTransitionSecondsRemaining, 1);

        controller.pause(); // freeze at 1s remaining
        async.elapse(const Duration(seconds: 30));
        expect(container.read(matchControllerProvider).roundTransitionSecondsRemaining, 1,
            reason: 'Even 1s remaining is preserved through the background');

        controller.resume();
        async.elapse(const Duration(seconds: 1));
        final ui = container.read(matchControllerProvider);
        expect(ui.match.currentRound, 2, reason: 'Remaining 1s completes on the first tick');
        expect(ui.roundTransitionSecondsRemaining, 0);
        expect(ui.isSchedulingPaused, false);

        async.elapse(const Duration(seconds: 5));
        expect(container.read(matchControllerProvider).match.currentRound, 2,
            reason: 'No duplicate transition');
      });
    });

    test('REPRO: restarting the match while frozen clears the stale countdown', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer();
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        controller.pause();
        expect(container.read(matchControllerProvider).isSchedulingPaused, true);

        controller.startMatch();
        var ui = container.read(matchControllerProvider);
        expect(ui.isSchedulingPaused, false);
        expect(ui.roundTransitionSecondsRemaining, 0);
        expect(ui.match.currentRound, 1);
        expect(ui.match.isRoundOver, false);

        async.elapse(const Duration(seconds: 10));
        ui = container.read(matchControllerProvider);
        expect(ui.match.currentRound, 1, reason: 'No stale transition after restart');
        expect(ui.isSchedulingPaused, false);
        expect(ui.match.isRoundOver, false);
      });
    });

    test('leaving the screen while frozen disposes the provider and stops all work', () {
      fakeAsync((async) {
        final time = FakeTimeSource();
        final container = ProviderContainer(
          overrides: [
            matchConfigProvider.overrideWithValue(config()),
            timeSourceProvider.overrideWithValue(time),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(matchControllerProvider.notifier);
        winRoundForX(controller, xStarts: true);
        controller.pause();
        expect(container.read(matchControllerProvider).isSchedulingPaused, true);

        // The screen unmounts: autoDispose tears the controller down.
        final sub = container.listen(matchControllerProvider, (_, _) {});
        sub.close();

        async.elapse(const Duration(seconds: 10));
        expect(controller.currentRound, 1,
            reason: 'Frozen scheduling must not run after disposal');
        expect(controller.isRoundOver, true);
        expect(controller.roundTransitionSecondsRemaining, 0);
      });
    });
  });

  group('MatchController - System Role & Stale Results', () {
    test('REPRO: the system opens the round automatically when it starts', () {
      fakeAsync((async) {
        final port = FakeSystemMovePort()
          ..enqueueImmediate(const Position(2, 2));
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 1, vsSystem: true, human: Player.o),
          movePort: port,
        );
        addTearDown(container.dispose);

        async.flushMicrotasks();
        expect(port.callCount, 1);
        expect(controller.snapshot.match.roundState.moveHistory.length, 1,
            reason: 'The system (X) plays the opening move automatically');
        expect(
            controller.snapshot.match.roundState.board.cellAt(const Position(2, 2)),
            Player.x);
        expect(controller.currentTurnPlayer, Player.o, reason: 'Human O next');
      });
    });

    test('REPRO: the system replies after the human move and never '
        're-requests during the human turn', () {
      fakeAsync((async) {
        final port = FakeSystemMovePort()
          ..enqueueImmediate(const Position(1, 1));
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 3, vsSystem: true, human: Player.x),
          movePort: port,
        );
        addTearDown(container.dispose);

        controller.makeMove(const Position(0, 0)); // human X
        async.flushMicrotasks();
        expect(port.callCount, 1);
        expect(controller.snapshot.match.roundState.board.cellAt(const Position(1, 1)),
            Player.o,
            reason: 'The system replied through the engine');
        expect(controller.currentTurnPlayer, Player.x);

        // Extra time and notifications must not re-request during the
        // human's turn.
        async.elapse(const Duration(seconds: 5));
        expect(port.callCount, 1);
      });
    });

    test('starter alternation and fixed marks across vs-system rounds', () {
      fakeAsync((async) {
        final port = FakeSystemMovePort()
          ..enqueueImmediate(const Position(0, 0)); // system opens (0,0)
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 3, vsSystem: true, human: Player.o),
          movePort: port,
        );
        addTearDown(container.dispose);

        // Round 1: starter X = SYSTEM → opens automatically.
        async.flushMicrotasks();
        expect(controller.snapshot.match.roundState.board.cellAt(const Position(0, 0)),
            Player.x);
        expect(controller.currentTurnPlayer, Player.o);
        final callsAfterRound1Start = port.callCount;
        expect(callsAfterRound1Start, 1);

        // Human moves; the system replies (default first-empty (0,1)).
        controller.makeMove(const Position(1, 0)); // human O
        async.flushMicrotasks();
        expect(port.callCount, callsAfterRound1Start + 1);
        expect(controller.snapshot.match.roundState.board.cellAt(const Position(0, 1)),
            Player.x, reason: 'The system always plays X in this match');

        // Human (2,2); the system completes row 0 → X wins round 1.
        controller.makeMove(const Position(2, 2)); // human O
        async.flushMicrotasks();
        expect(port.callCount, callsAfterRound1Start + 2);
        expect(controller.isRoundOver, true, reason: 'X completed row 0');
        expect(controller.snapshot.match.scoreX, 1);

        // Round 2: starter O = HUMAN → no system request at round start.
        controller.nextRound();
        async.flushMicrotasks();
        expect(controller.currentRound, 2);
        expect(controller.roundStartingPlayer, Player.o);
        expect(controller.currentTurnPlayer, Player.o);
        expect(port.callCount, callsAfterRound1Start + 2,
            reason: 'Round 2 starts with the HUMAN — no system request');

        // The human moves; the system replies with its fixed X mark.
        controller.makeMove(const Position(1, 0)); // O
        async.flushMicrotasks();
        expect(port.callCount, callsAfterRound1Start + 3);
        expect(controller.snapshot.match.roundState.board.cellAt(const Position(0, 0)),
            Player.x, reason: 'Marks stay fixed across rounds');
      });
    });

    test('REPRO: a stale system move from before a restart is discarded and '
        'the fresh match still gets its move', () {
      fakeAsync((async) {
        final gate = Completer<Position?>();
        final port = FakeSystemMovePort()..enqueueGate(gate);
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 1, vsSystem: true, human: Player.o),
          movePort: port,
        );
        addTearDown(container.dispose);

        async.flushMicrotasks();
        expect(port.callCount, 1, reason: 'system X opens round 1');

        // Restart while the system move is in flight.
        controller.startMatch();
        expect(controller.snapshot.match.roundState.moveHistory, isEmpty);

        // The OLD request completes with a move for the OLD board: discarded,
        // and the fresh match re-requests — the system (X) opens it.
        gate.complete(const Position(1, 1));
        async.flushMicrotasks();

        expect(port.callCount, 2);
        expect(controller.snapshot.match.roundState.moveHistory.length, 1,
            reason: 'The fresh match proceeds with a fresh system move');
        expect(controller.snapshot.match.roundState.board.cellAt(const Position(0, 0)),
            Player.x);
        expect(controller.currentTurnPlayer, Player.o,
            reason: 'the human O is next in the fresh match');
      });
    });

    test('REPRO: resetting the round during thinking discards the stale move',
        () {
      fakeAsync((async) {
        final gate = Completer<Position?>();
        final port = FakeSystemMovePort()..enqueueGate(gate);
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 3, vsSystem: true, human: Player.x),
          movePort: port,
        );
        addTearDown(container.dispose);

        controller.makeMove(const Position(0, 0)); // human X
        async.flushMicrotasks();
        expect(port.callCount, 1, reason: 'system O thinking');

        controller.resetCurrentRound();
        gate.complete(const Position(1, 1));
        async.flushMicrotasks();

        expect(controller.snapshot.match.roundState.moveHistory, isEmpty,
            reason: 'The stale move must not land on the fresh round');
        expect(controller.currentTurnPlayer, Player.x);
        // The fresh round re-requests the system move after the human plays.
        controller.makeMove(const Position(0, 1));
        async.flushMicrotasks();
        expect(port.callCount, 2);
      });
    });

    test('REPRO: the chess clock expiring during thinking loses the round '
        'and the stale move is discarded', () {
      fakeAsync((async) {
        final gate = Completer<Position?>();
        final time = FakeTimeSource();
        final port = FakeSystemMovePort()..enqueueGate(gate);
        final (container, controller) = buildContainer(
          matchConfig: config(
              rounds: 1, timer: true, vsSystem: true, human: Player.o),
          movePort: port,
          timeSource: time,
        );
        addTearDown(container.dispose);

        async.flushMicrotasks();
        expect(port.callCount, 1, reason: 'system X thinking');

        // The system's clock runs out while thinking.
        time.advance(const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 1));
        expect(controller.isRoundOver, true,
            reason: 'The system loses on time');
        expect(controller.roundEndReason, RoundEndReason.timeout);
        expect(controller.roundWinner, Player.o, reason: 'The human wins');

        // The stale opening request completes afterwards: discarded —
        // the system lost on time, so nothing is applied.
        gate.complete(const Position(1, 1));
        async.flushMicrotasks();
        expect(controller.isRoundOver, true);
        expect(controller.snapshot.match.roundState.moveHistory, isEmpty,
            reason: 'The stale opening request was discarded on timeout');
      });
    });

    test('pause during thinking: no application; manual resume re-requests',
        () {
      fakeAsync((async) {
        final gate = Completer<Position?>();
        final port = FakeSystemMovePort()..enqueueGate(gate);
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 1, vsSystem: true, human: Player.o),
          movePort: port,
        );
        addTearDown(container.dispose);

        async.flushMicrotasks();
        expect(port.callCount, 1);

        controller.pause();
        gate.complete(const Position(2, 2));
        async.flushMicrotasks();
        expect(controller.isPaused, true);
        expect(controller.snapshot.match.roundState.moveHistory, isEmpty,
            reason: 'No application while paused');

        controller.resume();
        async.flushMicrotasks();
        expect(port.callCount, 2,
            reason: 'Manual resume re-requests the system move');
        // The fresh request (default first-empty) applies.
        async.flushMicrotasks();
        expect(controller.snapshot.match.roundState.board.cellAt(const Position(0, 0)),
            Player.x);
        expect(controller.isPaused, false);
      });
    });

    test('local play never requests a system move', () {
      fakeAsync((async) {
        final port = FakeSystemMovePort();
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 3, vsSystem: false, human: Player.x),
          movePort: port,
        );
        addTearDown(container.dispose);

        controller.makeMove(const Position(0, 0));
        async.flushMicrotasks();
        controller.makeMove(const Position(1, 1));
        async.flushMicrotasks();
        expect(port.callCount, 0,
            reason: 'Local two-player mode never touches the system port');
      });
    });

    test('port failure falls back to direct calculation and keeps play progressing',
        () {
      fakeAsync((async) {
        final port = FakeSystemMovePort()
          ..enqueueError(UnsupportedError('dart:isolate is not supported on dart4web'));
        final (container, controller) = buildContainer(
          matchConfig: config(rounds: 1, vsSystem: true, human: Player.o),
          movePort: port,
        );
        addTearDown(container.dispose);

        // System is X, starts the game. Port is invoked and fails with UnsupportedError.
        async.flushMicrotasks();
        expect(port.callCount, 1);

        // The fallback should have calculated the move directly and applied it.
        expect(
          controller.snapshot.match.roundState.moveHistory.isNotEmpty,
          true,
          reason: 'System move must be applied via fallback despite port failure',
        );
        expect(
          controller.snapshot.match.roundState.moveHistory.first.player,
          Player.x,
        );
        expect(
          controller.currentTurnPlayer,
          Player.o,
          reason: 'Turn must advance to human player O without freezing',
        );
      });
    });
  });

  group('MatchController - Final Result Policy', () {
    test('REPRO: backgrounding during the result delay freezes the presentation', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer(matchConfig: config(rounds: 1));
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        expect(controller.isRoundOver, true);
        expect(controller.isMatchOver, false);

        // App enters the background: presentation frozen, nothing concludes.
        controller.pause(freezeResultPresentation: true);
        async.elapse(const Duration(seconds: 10));
        expect(controller.isMatchOver, false,
            reason: 'The result presentation must not complete in the background');
        expect(controller.isRoundOver, true);
      });
    });

    test('returning to the foreground presents the frozen result immediately without manual resume', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer(matchConfig: config(rounds: 1));
        addTearDown(container.dispose);

        var presentedCount = 0;
        container.listen(matchControllerProvider, (previous, next) {
          if (!(previous?.match.isMatchOver ?? false) && next.match.isMatchOver) {
            presentedCount++;
          }
        });

        winRoundForX(controller, xStarts: true);
        controller.pause(freezeResultPresentation: true); // background during delay

        // Return to the foreground: result appears IMMEDIATELY.
        container.read(matchControllerProvider.notifier).onAppResumed();
        expect(controller.isMatchOver, true,
            reason: 'Result is presented on return without manual resume');
        expect(controller.matchWinner, Player.x);

        // Exactly one presentation; a repeated return is a no-op.
        container.read(matchControllerProvider.notifier).onAppResumed();
        expect(presentedCount, 1, reason: 'No duplicate result presentation');
        expect(controller.isMatchOver, true);
        expect(controller.scoreX, 1);
      });
    });

    test('REPRO: restarting clears a frozen pending result; a stale return cannot resurrect it', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer(matchConfig: config(rounds: 1));
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        controller.pause(freezeResultPresentation: true); // pending frozen

        // Player restarts the match while the result is pending.
        controller.startMatch();
        final matchAfterRestart = controller.snapshot.match;
        expect(controller.isMatchOver, false);

        // Stale return: must NOT resurrect the old result.
        container.read(matchControllerProvider.notifier).onAppResumed();
        expect(controller.isMatchOver, false, reason: 'Stale pending result was dropped');
        expect(identical(controller.snapshot.match, matchAfterRestart), isTrue);

        // The NEW match concludes normally on its own delay.
        winRoundForX(controller, xStarts: true);
        async.elapse(const Duration(milliseconds: 1300));
        expect(controller.isMatchOver, true);
        expect(controller.matchWinner, Player.x);
        expect(controller.scoreX, 1);
      });
    });

    test('clock does not continue after the match ends', () {
      fakeAsync((async) {
        final (container, controller) =
            buildContainer(matchConfig: config(rounds: 1, timer: true));
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        async.elapse(const Duration(milliseconds: 1300));
        expect(controller.isMatchOver, true);

        final remX = controller.remainingTimeX;
        final remO = controller.remainingTimeO;
        async.elapse(const Duration(seconds: 30));
        expect(controller.remainingTimeX, remX,
            reason: 'The chess clock must freeze after the match ends');
        expect(controller.remainingTimeO, remO);
        expect(controller.isMatchOver, true);
      });
    });

    test('REPRO: resetting during a frozen pending result drops the stale presentation', () {
      fakeAsync((async) {
        final (container, controller) = buildContainer(matchConfig: config(rounds: 1));
        addTearDown(container.dispose);

        winRoundForX(controller, xStarts: true);
        controller.pause(freezeResultPresentation: true); // pending frozen

        // Player resets the round while the result presentation is pending.
        controller.resetCurrentRound();
        expect(controller.isRoundOver, false);
        expect(controller.isMatchOver, false);

        // Stale return: must NOT resurrect the old result.
        container.read(matchControllerProvider.notifier).onAppResumed();
        expect(controller.isMatchOver, false, reason: 'Stale pending result was dropped');
        expect(controller.snapshot.match.roundState.moveHistory, isEmpty,
            reason: 'The fresh round is untouched');

        // The fresh round is playable.
        controller.makeMove(const Position(0, 0));
        expect(controller.currentTurnPlayer, Player.o);
      });
    });

    group('MatchController - System Thinking Delay & Feedback (Problem 10)', () {
      test('system thinking sets isSystemThinking true and applies move after delay', () {
        fakeAsync((async) {
          final port = FakeSystemMovePort()
            ..enqueueImmediate(const Position(1, 1));
          final (container, controller) = buildContainer(
            matchConfig: config(rounds: 1, vsSystem: true, human: Player.x),
            movePort: port,
            systemThinkingDelay: const Duration(milliseconds: 500),
          );
          addTearDown(container.dispose);

          // Human plays (0, 0)
          controller.makeMove(const Position(0, 0));
          async.flushMicrotasks();

          // System is thinking
          expect(controller.snapshot.isSystemThinking, isTrue);
          expect(controller.snapshot.match.roundState.board.isEmpty(const Position(1, 1)), isTrue);

          // Advance 250ms (delay half elapsed)
          async.elapse(const Duration(milliseconds: 250));
          expect(controller.snapshot.isSystemThinking, isTrue);

          // Advance another 250ms (total 500ms)
          async.elapse(const Duration(milliseconds: 250));
          async.flushMicrotasks();

          // Move is now applied and thinking flag cleared
          expect(controller.snapshot.isSystemThinking, isFalse);
          expect(controller.snapshot.match.roundState.board.cellAt(const Position(1, 1)), Player.o);
        });
      });
    });

    group('MatchController - Difficulty Progression Integration (Problem 5)', () {
      test('concluding vs-system match records outcome in progression service', () {
        fakeAsync((async) {
          final (container, controller) = buildContainer(
            matchConfig: config(rounds: 1, vsSystem: true, human: Player.x),
          );
          addTearDown(container.dispose);

          final progression = container.read(difficultyProgressionServiceProvider);
          expect(progression.state.consecutiveWins, 0);

          // Human X wins the match
          winRoundForX(controller, xStarts: true);
          async.elapse(const Duration(milliseconds: 1300)); // finalize delay

          expect(controller.isMatchOver, isTrue);
          expect(progression.state.consecutiveWins, 1);
          expect(progression.state.totalWins, 1);
        });
      });
    });
  });
}
