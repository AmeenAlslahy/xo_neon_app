import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

/// EXPLORATORY STRENGTH MEASUREMENT — intentionally separate from the
/// correctness tests and EXCLUDED from the default `flutter test` run.
/// Run explicitly: `flutter test --run-skipped
/// test/features/game/domain/ai/system_move_selector_strength_test.dart`
///
/// Sparring matches: the HARD selector vs deterministic sparring partners
/// (easy-with-fixed-seed and medium), fixed seeds, BOTH play sides (starter
/// alternation via GameEngine.reset), a small fixed number of games per
/// configuration. The tallies are REPORTED AS MEASURED — a small sample is
/// NOT absolute proof of superiority. There are NO time caps here either.
///
/// Measurement environment: Windows 10.0.19045 x64 development machine,
/// Flutter 3.47.2 / Dart 3.13.2 host test VM (debug mode) — NOT an
/// on-device profile.
void main() {
  /// Plays one full game: [systemMark] is the hard selector's mark; the
  /// sparring partner plays the other side. Returns 1 win / 0 draw / −1 loss
  /// from the system's perspective, or null if the game stalls.
  int? playGame(
    SystemMoveSelector system,
    Player systemMark,
    SystemMoveSelector sparring,
    BoardConfig config,
    Random rng,
  ) {
    final engine = GameEngine(config: config);
    var guard = 0;
    while (!engine.state.isGameOver && guard++ < config.totalCells + 2) {
      final mover = engine.state.currentPlayer;
      final selector = mover == systemMark ? system : sparring;
      final move = selector.selectMove(engine.state);
      if (move == null) {
        return null; // no move available (should not happen pre-full-board)
      }
      engine.makeMove(move);
    }
    final status = engine.state.status;
    if (status is GameWon) {
      return status.winner == systemMark ? 1 : -1;
    }
    return 0; // draw
  }

  /// Plays [games] with starter alternation (GameEngine.reset) and returns
  /// the tally string.
  String playSeries(
    String label,
    SystemMoveSelector system,
    SystemMoveSelector sparring,
    BoardConfig config,
    Random rng,
    int games,
  ) {
    var wins = 0;
    var draws = 0;
    var losses = 0;
    for (var i = 0; i < games; i++) {
      final result = playGame(system, i.isEven ? Player.x : Player.o, sparring, config, rng);
      if (result == 1) {
        wins++;
      } else if (result == 0) {
        draws++;
      } else {
        losses++;
      }
    }
    return '$label: W=$wins D=$draws L=$losses (of $games)';
  }

  test(
    'strength: hard vs easy/medium sparring across the large sizes (fixed seeds)',
    () {
      final hard = SearchMoveSelector();
      final rng = Random(20261107);
      const sizes = [6, 9, 11];

      for (final size in sizes) {
        final config = BoardConfig.fromSize(size);
        final easyX = RandomMoveSelector(random: Random(rng.nextInt(1 << 30)));
        const medium = HeuristicMoveSelector();

        // ignore: avoid_print
        print(playSeries('hard-vs-easy ${size}x$size', hard, easyX, config,
            Random(rng.nextInt(1 << 30)), 6));
        // ignore: avoid_print
        print(playSeries('hard-vs-medium ${size}x$size', hard, medium, config,
            Random(rng.nextInt(1 << 30)), 6));
      }
    },
    skip: 'Exploratory strength measurement — excluded from the default suite. '
        'Run explicitly: flutter test --run-skipped '
        'test/features/game/domain/ai/system_move_selector_strength_test.dart',
  );
}
