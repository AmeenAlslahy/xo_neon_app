import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  GameState stateAfter(List<Position> moves, {required BoardConfig config}) {
    final engine = GameEngine(config: config);
    for (final move in moves) {
      engine.makeMove(move);
    }
    return engine.state;
  }

  group('Fork & Double Threat Detection (Problem 3)', () {
    test('hard creates an immediate double threat / fork on 6x6', () {
      // 6x6, winStreak 4
      // X has: (2, 1), (2, 2) on row 2, and (1, 3), (3, 3) on col 3
      // Empty cell (2, 3) intersects row 2 and col 3!
      // If X plays (2, 3):
      // - row 2 gets (2,1), (2,2), (2,3) -> threats at (2,0) and (2,4)
      // - col 3 gets (1,3), (2,3), (3,3) -> threats at (0,3) and (4,3)
      // Multiple distinct winning cells!
      final state = stateAfter(const [
        Position(2, 1), // X
        Position(0, 0), // O
        Position(2, 2), // X
        Position(5, 5), // O
        Position(1, 3), // X
        Position(0, 5), // O
        Position(3, 3), // X
        Position(5, 0), // O
      ], config: BoardConfig.fromSize(6));

      expect(state.currentPlayer, Player.x);

      final hard = SearchMoveSelector();
      final move = hard.selectMove(state);

      expect(move, const Position(2, 3), reason: 'Hard must play the fork intersection (2,3)');
    });

    test('hard blocks opponent immediate double threat / fork on 6x6', () {
      // 6x6, winStreak 4
      // X has: (2, 1), (2, 2) on row 2, and (1, 3), (3, 3) on col 3
      // O is to move. If O does not play (2, 3), X plays (2, 3) next turn and creates an unstoppable fork!
      // O MUST block the fork at (2, 3)!
      final state = stateAfter(const [
        Position(2, 1), // X
        Position(0, 0), // O
        Position(2, 2), // X
        Position(5, 5), // O
        Position(1, 3), // X
        Position(0, 5), // O
        Position(3, 3), // X
      ], config: BoardConfig.fromSize(6));

      expect(state.currentPlayer, Player.o);

      final hard = SearchMoveSelector();
      final move = hard.selectMove(state);

      expect(move, const Position(2, 3), reason: 'Hard must block the fork intersection (2,3)');
    });

    test('evaluation includes +5000 / -5000 fork bonus', () {
      // Board with a completed fork for X
      final config = BoardConfig.fromSize(6);
      final state = stateAfter(const [
        Position(2, 1), // X
        Position(0, 0), // O
        Position(2, 2), // X
        Position(5, 5), // O
        Position(1, 3), // X
        Position(0, 5), // O
        Position(3, 3), // X
        Position(5, 0), // O
        Position(2, 3), // X plays fork!
        Position(4, 4), // O plays irrelevant
      ], config: config);

      final hard = SearchMoveSelector();
      final evalX = hard.evaluateBoard(state.board, Player.x);
      final evalO = hard.evaluateBoard(state.board, Player.o);

      expect(evalX, greaterThanOrEqualTo(5000), reason: 'X has a fork, so evalX must have >= 5000 bonus');
      expect(evalO, lessThanOrEqualTo(-5000), reason: 'O faces a fork, so evalO must be <= -5000');
    });
  });
}
