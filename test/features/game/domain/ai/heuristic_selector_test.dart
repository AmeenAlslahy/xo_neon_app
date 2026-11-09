import 'dart:math';

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

  group('HeuristicMoveSelector - Open Threat Defense (Problem 1)', () {
    test('medium blocks horizontal _ P P _ threat at >= 80% across 100 trials', () {
      final config = BoardConfig.fromSize(6);
      // Moves: X(2,2), O(0,0), X(2,3) -> O to move facing _ X X _ on row 2
      final state = stateAfter([
        const Position(2, 2), // X
        const Position(0, 0), // O
        const Position(2, 3), // X
      ], config: config);

      expect(state.currentPlayer, Player.o);

      var blockedCount = 0;
      const trials = 100;
      for (var seed = 0; seed < trials; seed++) {
        final selector = HeuristicMoveSelector(random: Random(seed));
        final move = selector.selectMove(state);
        // Valid blocks are (2, 1) or (2, 4)
        if (move == const Position(2, 1) || move == const Position(2, 4)) {
          blockedCount++;
        }
      }

      expect(
        blockedCount,
        greaterThanOrEqualTo(80),
        reason: 'Medium AI must block open-two _ P P _ at least 80% of the time, got $blockedCount/100',
      );
    });

    test('medium blocks vertical _ P P _ threat at >= 80% across 100 trials', () {
      final config = BoardConfig.fromSize(6);
      // Moves: X(2,2), O(0,5), X(3,2) -> O to move facing vertical _ X X _ on col 2
      final state = stateAfter([
        const Position(2, 2), // X
        const Position(0, 5), // O
        const Position(3, 2), // X
      ], config: config);

      expect(state.currentPlayer, Player.o);

      var blockedCount = 0;
      const trials = 100;
      for (var seed = 0; seed < trials; seed++) {
        final selector = HeuristicMoveSelector(random: Random(seed));
        final move = selector.selectMove(state);
        if (move == const Position(1, 2) || move == const Position(4, 2)) {
          blockedCount++;
        }
      }

      expect(blockedCount, greaterThanOrEqualTo(80));
    });

    test('medium blocks diagonal _ P P _ threat at >= 80% across 100 trials', () {
      final config = BoardConfig.fromSize(6);
      // Moves: X(2,2), O(0,0), X(3,3) -> O to move facing diagonal _ X X _
      final state = stateAfter([
        const Position(2, 2), // X
        const Position(0, 0), // O
        const Position(3, 3), // X
      ], config: config);

      expect(state.currentPlayer, Player.o);

      var blockedCount = 0;
      const trials = 100;
      for (var seed = 0; seed < trials; seed++) {
        final selector = HeuristicMoveSelector(random: Random(seed));
        final move = selector.selectMove(state);
        if (move == const Position(1, 1) || move == const Position(4, 4)) {
          blockedCount++;
        }
      }

      expect(blockedCount, greaterThanOrEqualTo(80));
    });

    test('hard (SearchMoveSelector) blocks open-two 100% of the time', () {
      final config = BoardConfig.fromSize(6);
      final state = stateAfter([
        const Position(2, 2), // X
        const Position(0, 0), // O
        const Position(2, 3), // X
      ], config: config);

      expect(state.currentPlayer, Player.o);

      final hard = SearchMoveSelector();
      final move = hard.selectMove(state);
      expect(
        move == const Position(2, 1) || move == const Position(2, 4),
        isTrue,
        reason: 'Hard AI must block open-two 100% of the time, got $move',
      );
    });

    test('immediate win and immediate block take strict priority over open-two', () {
      final config = BoardConfig.fromSize(6);
      // X has open-two at (3,2),(3,3). But O has (1,1),(1,2),(1,3) which wins at (1,4)!
      final state = stateAfter([
        const Position(3, 2), // X
        const Position(1, 1), // O
        const Position(3, 3), // X
        const Position(1, 2), // O
        const Position(0, 0), // X
        const Position(1, 3), // O
        const Position(5, 5), // X
      ], config: config);

      expect(state.currentPlayer, Player.o);

      const medium = HeuristicMoveSelector();
      final move = medium.selectMove(state);
      expect(
        move == const Position(1, 0) || move == const Position(1, 4),
        isTrue,
        reason: 'Immediate win takes priority over blocking, got $move',
      );
    });
  });
}
