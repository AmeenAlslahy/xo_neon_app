// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  group('AI Benchmark — Search Performance & Depth Analysis', () {
    final configs = [
      ('6x6 (WinStreak 4)', BoardConfig.grid6x6),
      ('9x9 (WinStreak 5)', BoardConfig.grid9x9),
      ('11x11 (WinStreak 6)', BoardConfig.grid11x11),
    ];

    final difficulties = [
      SystemDifficulty.hard,
      SystemDifficulty.expert,
      SystemDifficulty.master,
    ];

    for (final (label, config) in configs) {
      test('Benchmark $label across search difficulty levels', () {
        // Construct a realistic active position: human played center/near-center moves
        final centerRow = config.rows ~/ 2;
        final centerCol = config.cols ~/ 2;

        var board = GameBoard.empty(config);
        board = board.copyWithMove(Position(centerRow, centerCol), Player.x);

        final state = GameState(
          config: config,
          board: board,
          startingPlayer: Player.x,
          currentPlayer: Player.o,
          status: const GameInProgress(Player.o),
          moveHistory: const [],
        );

        print('\n============================================================');
        print('BENCHMARK: $label');
        print('Board Size: ${config.rows}x${config.cols}, WinStreak: ${config.winStreak}');
        print('------------------------------------------------------------');
        print(
          'Level'.padRight(10) +
          'Elapsed (ms)'.padRight(16) +
          'Target Depth'.padRight(16) +
          'Actual Depth'.padRight(16) +
          'Status',
        );
        print('------------------------------------------------------------');

        for (final difficulty in difficulties) {
          final selector = SystemMoveSelector.forDifficulty(difficulty);
          expect(selector, isA<SearchMoveSelector>());
          final searchSelector = selector as SearchMoveSelector;

          final sw = Stopwatch()..start();
          final move = searchSelector.selectMove(state);
          sw.stop();

          final elapsedMs = sw.elapsedMilliseconds;
          final targetDepth = searchSelector.targetDepth(config);
          final actualDepth = searchSelector.lastCompletedDepth;
          final reachedTarget = actualDepth >= targetDepth;
          final status = reachedTarget
              ? 'Reached target depth'
              : 'Stopped by time budget (${searchSelector.effectiveTimeBudgetMs}ms)';

          print(
            difficulty.name.padRight(10) +
            '${elapsedMs}ms'.padRight(16) +
            '$targetDepth'.padRight(16) +
            '$actualDepth'.padRight(16) +
            status,
          );

          expect(move, isNotNull);
          expect(board.isEmpty(move!), isTrue);
          expect(actualDepth, greaterThanOrEqualTo(1));
          expect(elapsedMs, lessThanOrEqualTo(searchSelector.effectiveTimeBudgetMs + 500));
        }
        print('============================================================\n');
      });
    }
  });
}
