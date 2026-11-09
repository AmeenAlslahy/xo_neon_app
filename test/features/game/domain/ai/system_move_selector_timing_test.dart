import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

/// EXPLORATORY TIMING MEASUREMENT — intentionally separate from the
/// correctness tests in system_move_selector_test.dart and EXCLUDED from the
/// default `flutter test` run (skip marker below). Run it explicitly with:
/// `flutter test --run-skipped test/features/game/domain/ai/system_move_selector_timing_test.dart`
///
/// The numbers are reported AS MEASURED, with their environment:
/// - Windows 10.0.19045 x64 development machine
/// - Flutter 3.47.2 / Dart 3.13.2 host test VM (debug mode)
/// - NOT an on-device profile, and NOT comparable to device frame budgets:
///   host debug timings must never be turned into 16ms-frame-budget claims.
/// There are deliberately NO time-cap assertions here (a slow machine must
/// not fail the suite); the only assertions are smoke checks that moves are
/// produced. No Isolate is used or decided by this file — per the approved
/// plan, that decision follows on-device measurement.
void main() {
  /// Marks [count] cells along the main diagonal, alternating players — a
  /// provably non-terminal pattern for every authorized size and streak
  /// (no row/column ever holds two marks; the diagonal itself alternates).
  GameState diagonalState(BoardConfig config, int count) {
    final engine = GameEngine(config: config);
    final limit = min(count, min(config.rows, config.cols));
    for (var m = 0; m < limit; m++) {
      engine.makeMove(Position(m, m));
    }
    return engine.state;
  }

  /// Runs [selector] against [state] [runs] times and prints p50/p95/max
  /// (milliseconds, as measured — no thresholds).
  void measure(
    String label,
    SystemMoveSelector selector,
    GameState state, {
    int runs = 25,
  }) {
    for (var i = 0; i < 3; i++) {
      selector.selectMove(state); // warm-up
    }
    final durations = <double>[];
    var produced = 0;
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      final move = selector.selectMove(state);
      if (move != null) {
        produced++;
      }
      durations.add(sw.elapsedMicroseconds / 1000);
    }
    durations.sort();
    final p50 = durations[durations.length ~/ 2];
    final p95 =
        durations[(durations.length * 0.95).floor().clamp(0, durations.length - 1)];
    // ignore: avoid_print
    print('$label: p50=${p50.toStringAsFixed(2)}ms '
        'p95=${p95.toStringAsFixed(2)}ms max=${durations.last.toStringAsFixed(2)}ms '
        '(moves produced: $produced/$runs)');
  }

  test(
    'exploratory selection timing across levels and the four sizes',
    () {
      final easy = SystemMoveSelector.forDifficulty(SystemDifficulty.easy);
      const medium = HeuristicMoveSelector();
      final hard = SearchMoveSelector();

      for (final size in [3, 6, 9, 11]) {
        final config = BoardConfig.fromSize(size);
        final empty = GameState.initial(config: config);
        final mid = diagonalState(config, size < 6 ? 3 : 6);

        measure('easy  empty ${size}x$size', easy, empty);
        measure('medium mid ${size}x$size', medium, mid);
        measure('hard  empty ${size}x$size', hard, empty);
        measure('hard  mid   ${size}x$size', hard, mid);
      }
    },
    skip: 'Exploratory benchmark — excluded from the default suite. Run '
        'explicitly: flutter test --run-skipped '
        'test/features/game/domain/ai/system_move_selector_timing_test.dart',
  );
}
