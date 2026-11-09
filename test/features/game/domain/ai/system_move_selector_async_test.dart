import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

/// The async entry point (used on Flutter Web) must be move-for-move
/// identical to the synchronous search: yielding between root branches may
/// change WHEN work runs, never WHAT it concludes.
void main() {
  GameState stateWith({
    required BoardConfig config,
    required Map<Position, Player> stones,
    required Player turn,
  }) {
    final cells = List<Player?>.filled(config.totalCells, null);
    stones.forEach((position, player) {
      cells[position.row * config.cols + position.col] = player;
    });
    return GameState(
      config: config,
      board: GameBoard.fromCells(config, cells),
      startingPlayer: Player.x,
      currentPlayer: turn,
      status: GameInProgress(turn),
      moveHistory: const [],
    );
  }

  test('async matches sync on the 6×6 open-two defense', () async {
    final state = stateWith(
      config: BoardConfig.grid6x6,
      stones: {
        const Position(2, 2): Player.o,
        const Position(2, 3): Player.o,
        const Position(5, 0): Player.x,
        const Position(0, 5): Player.x,
      },
      turn: Player.x,
    );
    final sync = SearchMoveSelector().selectMove(state);
    final asyncMove = await SearchMoveSelector().selectMoveAsync(state);
    expect(asyncMove, sync);
    expect(asyncMove, anyOf(const Position(2, 1), const Position(2, 4)));
  });

  test('async matches sync on 9×9 and 11×11 line threats', () async {
    final cases = [
      (
        config: BoardConfig.grid9x9,
        stones: <Position, Player>{
          const Position(4, 3): Player.o,
          const Position(4, 4): Player.o,
          const Position(4, 5): Player.o,
          const Position(8, 0): Player.x,
          const Position(8, 1): Player.x,
          const Position(8, 2): Player.x,
        },
        ends: const [Position(4, 2), Position(4, 6)],
      ),
      (
        config: BoardConfig.grid11x11,
        stones: <Position, Player>{
          const Position(5, 3): Player.o,
          const Position(5, 4): Player.o,
          const Position(5, 5): Player.o,
          const Position(5, 6): Player.o,
          const Position(10, 0): Player.x,
          const Position(10, 1): Player.x,
          const Position(10, 2): Player.x,
          const Position(10, 3): Player.x,
        },
        ends: const [Position(5, 2), Position(5, 7)],
      ),
    ];
    for (final testCase in cases) {
      final state = stateWith(
        config: testCase.config,
        stones: testCase.stones,
        turn: Player.x,
      );
      final sync = SearchMoveSelector().selectMove(state);
      final asyncMove = await SearchMoveSelector().selectMoveAsync(state);
      expect(asyncMove, sync,
          reason: '${testCase.config.rows}×${testCase.config.cols}: '
              'async and sync must choose the same move');
      expect(testCase.ends, contains(asyncMove));
    }
  });

  test('async keeps the immediate-win priority', () async {
    final state = stateWith(
      config: BoardConfig.grid6x6,
      stones: {
        const Position(2, 0): Player.x,
        const Position(2, 1): Player.x,
        const Position(2, 2): Player.x,
        const Position(4, 0): Player.o,
        const Position(4, 1): Player.o,
        const Position(4, 2): Player.o,
      },
      turn: Player.x,
    );
    expect(
      await SearchMoveSelector().selectMoveAsync(state),
      const Position(2, 3),
    );
  });

  test('async delegates 3×3 to the exhaustive sync search', () async {
    final state = GameState.initial(config: BoardConfig.grid3x3);
    final sync = SearchMoveSelector().selectMove(state);
    final asyncMove = await SearchMoveSelector().selectMoveAsync(state);
    expect(asyncMove, sync);
    expect(asyncMove, const Position(1, 1));
  });
}
