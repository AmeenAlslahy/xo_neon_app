// Portable AI timing benchmark for Native (Dart VM) and Web (dart2js -> JS).
// Not part of the app or the widget test suite.
//
// Run on the Dart VM:
//   dart run tool/ai_bench.dart
//
// Compile to JavaScript and run in a JS engine (Node here, same dart2js
// output the web build executes):
//   dart compile js -O2 -o tool/build/ai_bench.js tool/ai_bench.dart
//   node tool/build/ai_bench.js
//
// Or run the same output in a browser (see tool/README.md).
//
// The workload mirrors system_move_selector_timing_test.dart: 3 warm-up
// selections, then 25 measured selections per case, reporting p50/p95/max in
// milliseconds. Numbers are as measured and carry no frame-budget claim.
import 'dart:math';

import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

GameState diagonalState(BoardConfig config, int count) {
  final engine = GameEngine(config: config);
  final limit = min(count, min(config.rows, config.cols));
  for (var m = 0; m < limit; m++) {
    engine.makeMove(Position(m, m));
  }
  return engine.state;
}

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
  print('$label: p50=${p50.toStringAsFixed(2)}ms '
      'p95=${p95.toStringAsFixed(2)}ms max=${durations.last.toStringAsFixed(2)}ms '
      '(moves produced: $produced/$runs)');
}

void main() {
  final hard = SearchMoveSelector();

  for (final size in [3, 6, 9, 11]) {
    final config = BoardConfig.fromSize(size);
    final empty = GameState.initial(config: config);
    final mid = diagonalState(config, size < 6 ? 3 : 6);

    measure('hard empty ${size}x$size', hard, empty);
    measure('hard mid   ${size}x$size', hard, mid);
  }
}
