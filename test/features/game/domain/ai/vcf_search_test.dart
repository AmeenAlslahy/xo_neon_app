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

  group('Victory by Continuous Fours (VCF) Search (Problem 4)', () {
    test('hard solves a 3-step VCF puzzle on 6x6 (depth 4 forced win)', () {
      // 6x6 board, winStreak = 4
      // Setup:
      // Row 2: (2, 0) is O, (2, 1) is X, (2, 3) is X. Cell (2, 2) is empty.
      // Playing (2, 2) creates a single threat on Row 2 at (2, 4). (Threat count = 1).
      // Col 2: (1, 2) is X, (4, 2) is X. Cell (3, 2) is empty.
      // (0, 1) is O (caps diagonal (0,1)-(1,2)-(2,3)).
      // Once O is forced to respond at (2, 4):
      // X then plays (3, 2), which completes Col 2: (1, 2), (2, 2), (3, 2), (4, 2) -> WIN!
      // Thus, playing (2, 2) is the unique forcing move of a guaranteed VCF win!
      final state = stateAfter(const [
        Position(2, 1), // X
        Position(2, 0), // O (caps left side of row 2)
        Position(2, 3), // X
        Position(0, 3), // O (caps anti-diagonal)
        Position(1, 2), // X
        Position(0, 1), // O (caps diagonal)
        Position(4, 2), // X
        Position(5, 0), // O
      ], config: BoardConfig.fromSize(6));

      expect(state.currentPlayer, Player.x);

      final hard = SearchMoveSelector();
      final move = hard.selectMove(state);

      // X must play (2, 2) to start the forcing VCF sequence
      expect(move, const Position(2, 2), reason: 'Hard must play the VCF key move (2, 2)');
    });

    test('hard executes the winning follow-up after forced block', () {
      final state = stateAfter(const [
        Position(2, 1), // X
        Position(2, 0), // O
        Position(2, 3), // X
        Position(0, 3), // O
        Position(1, 2), // X
        Position(0, 1), // O
        Position(4, 2), // X
        Position(5, 0), // O
        Position(2, 2), // X (forcing move)
        Position(2, 4), // O (forced block)
      ], config: BoardConfig.fromSize(6));

      expect(state.currentPlayer, Player.x);

      final hard = SearchMoveSelector();
      final move = hard.selectMove(state);

      // X now completes the line on col 2 by playing (3, 2) to win!
      expect(move, const Position(3, 2), reason: 'Hard must play (3, 2) for immediate win');
    });
  });
}
