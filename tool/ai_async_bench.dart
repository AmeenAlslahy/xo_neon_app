// Measures event-loop responsiveness of the sync vs async hard selector.
// A periodic 1 ms timer records the gap between ticks; a long blocking search
// produces one huge gap, while selectMoveAsync yields between chunks.
//
// Run on the VM:   dart run tool/ai_async_bench.dart
// Web-like JS:     dart compile js -O2 -o tool/build/ai_async_bench.js tool/ai_async_bench.dart
//                  node tool/run_async_bench.js   (adds Node's missing `self`)
// Browser:         node tool/run_edge_cdp.js     (Edge headless; see README)
import 'dart:async';
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

Future<void> measure(String label, GameState state) async {
  // Warm-up.
  for (var i = 0; i < 2; i++) {
    await SearchMoveSelector().selectMoveAsync(state);
  }

  final gaps = <double>[];
  final sw = Stopwatch()..start();
  var last = sw.elapsedMicroseconds;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = sw.elapsedMicroseconds;
    gaps.add((now - last) / 1000);
    last = now;
  });

  final total = Stopwatch()..start();
  await SearchMoveSelector().selectMoveAsync(state);
  total.stop();
  timer.cancel();

  _printGaps('$label async', total, gaps);
}

Future<void> measureSync(String label, GameState state) async {
  for (var i = 0; i < 2; i++) {
    SearchMoveSelector().selectMove(state);
  }

  final gaps = <double>[];
  final sw = Stopwatch()..start();
  var last = sw.elapsedMicroseconds;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = sw.elapsedMicroseconds;
    gaps.add((now - last) / 1000);
    last = now;
  });

  // Let the timer establish a baseline before the blocking call. Without
  // this, the timer never gets to run and no gap is recorded at all.
  await Future<void>.delayed(const Duration(milliseconds: 25));

  final total = Stopwatch()..start();
  SearchMoveSelector().selectMove(state);
  total.stop();
  // Let the periodic timer deliver the tick that was blocked by the search;
  // cancelling immediately would discard the very gap we want to record.
  await Future<void>.delayed(const Duration(milliseconds: 25));
  timer.cancel();

  _printGaps('$label sync ', total, gaps);
}

void _printGaps(String label, Stopwatch total, List<double> gaps) {
  gaps.sort();
  final p50 = gaps.isEmpty ? 0.0 : gaps[gaps.length ~/ 2];
  final p95 = gaps.isEmpty
      ? 0.0
      : gaps[(gaps.length * 0.95).floor().clamp(0, gaps.length - 1)];
  final maxGap = gaps.isEmpty ? 0.0 : gaps.last;
  print('$label: total=${total.elapsedMilliseconds}ms '
      'timerGap p50=${p50.toStringAsFixed(1)}ms '
      'p95=${p95.toStringAsFixed(1)}ms max=${maxGap.toStringAsFixed(1)}ms');
}

Future<void> main() async {
  for (final size in [6, 9, 11]) {
    final config = BoardConfig.fromSize(size);
    final state = diagonalState(config, 6);
    await measureSync('hard mid ${size}x$size', state);
    await measure('hard mid ${size}x$size', state);
  }
}
