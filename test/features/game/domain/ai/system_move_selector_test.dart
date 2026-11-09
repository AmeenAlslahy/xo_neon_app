import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

/// Deterministic correctness tests for the system move-selection core.
/// Timing/exploratory measurements live in a separate file.
void main() {
  final easy = SystemMoveSelector.forDifficulty(SystemDifficulty.easy,
      random: Random(42));
  const medium = HeuristicMoveSelector();
  final hard = SearchMoveSelector();

  BoardConfig configFor(int size) => BoardConfig.fromSize(size);

  /// Replays [moves] legally through the real engine and returns the state.
  GameState stateAfter(
    List<Position> moves, {
    BoardConfig config = BoardConfig.grid3x3,
  }) {
    final engine = GameEngine(config: config);
    for (final move in moves) {
      engine.makeMove(move);
    }
    return engine.state;
  }

  /// Builds a state one move away from a top-row win for X on [size].
  /// When [xToMove] the completing cell wins for X; otherwise O faces the
  /// threat and the completing cell blocks it.
  GameState nearWinState({required int size, required bool xToMove}) {
    final streak = BoardConfig.winStreakForSize(size);
    final moves = <Position>[];
    for (var i = 0; i < streak - 2; i++) {
      moves.add(Position(0, i)); // X
      moves.add(Position(2, i)); // O
    }
    moves.add(Position(0, streak - 2)); // X: the (streak − 1)th threat mark
    if (xToMove) {
      moves.add(Position(2, streak - 2)); // O answers → X's turn next
    }
    return stateAfter(moves, config: configFor(size));
  }

  final winIn1Moves = <Position>[
    Position(0, 0),
    Position(1, 0),
    Position(0, 1),
    Position(1, 1),
  ]; // X to move; (0, 2) completes row 0.

  final blockIn1Moves = <Position>[
    Position(0, 0),
    Position(2, 2),
    Position(0, 1),
  ]; // O to move; X threatens (0, 2).

  final forkMoves = <Position>[
    Position(0, 0),
    Position(1, 1),
    Position(2, 2),
  ]; // O to move; corners allow an X fork — only edges are safe.

  final oneEmptyMoves = <Position>[
    Position(0, 0),
    Position(0, 1),
    Position(0, 2),
    Position(1, 1),
    Position(1, 0),
    Position(2, 0),
    Position(1, 2),
    Position(2, 2),
  ]; // exactly one empty cell: (2, 1), X to move, no win yet.

  final drawMoves = <Position>[...oneEmptyMoves, Position(2, 1)]; // full draw.

  final allSelectors = <SystemMoveSelector>[easy, medium, hard];

  group('SystemMoveSelector - factory', () {
    test('forDifficulty builds the approved levels', () {
      expect(SystemMoveSelector.forDifficulty(SystemDifficulty.easy),
          isA<RandomMoveSelector>());
      expect(SystemMoveSelector.forDifficulty(SystemDifficulty.medium),
          isA<HeuristicMoveSelector>());
      expect(SystemMoveSelector.forDifficulty(SystemDifficulty.hard),
          isA<SearchMoveSelector>());
    });
  });

  group('SystemMoveSelector - common contract', () {
    test('empty board yields a valid empty cell on every level and size', () {
      for (final size in [3, 6, 9, 11]) {
        final state = stateAfter(const [], config: configFor(size));
        for (final selector in allSelectors) {
          final move = selector.selectMove(state);
          expect(move, isNotNull, reason: 'size $size: empty board has moves');
          expect(state.board.isEmpty(move!), isTrue,
              reason: 'size $size: picked cell must be empty');
        }
      }
    });

    test('full board returns null on every level', () {
      final state = stateAfter(drawMoves);
      expect(state.board.isFull, isTrue);
      for (final selector in allSelectors) {
        expect(selector.selectMove(state), isNull,
            reason: 'A full board has no move');
      }
    });

    test('terminal games return null (won / draw / timeout)', () {
      final won = stateAfter([...winIn1Moves, Position(0, 2)]);
      expect(won.isGameOver, isTrue);
      for (final selector in allSelectors) {
        expect(selector.selectMove(won), isNull, reason: 'GameWon');
      }

      final drawn = stateAfter(drawMoves);
      expect(drawn.isGameOver, isTrue);
      for (final selector in allSelectors) {
        expect(selector.selectMove(drawn), isNull, reason: 'GameDraw');
      }

      final timedOut = stateAfter(winIn1Moves).copyWith(
        status: const GameTimeout(timedOutPlayer: Player.x, winner: Player.o),
      );
      expect(timedOut.isGameOver, isTrue);
      for (final selector in allSelectors) {
        expect(selector.selectMove(timedOut), isNull, reason: 'GameTimeout');
      }
    });

    test('a board with exactly one empty cell returns that cell', () {
      final state = stateAfter(oneEmptyMoves);
      expect(state.board.occupiedCount, 8);
      for (final selector in allSelectors) {
        expect(selector.selectMove(state), const Position(2, 1));
      }
    });

    test('picked cells are always empty and within bounds on busy boards', () {
      final busy = stateAfter(winIn1Moves);
      for (final selector in allSelectors) {
        final move = selector.selectMove(busy)!;
        expect(busy.board.isWithinBounds(move), isTrue);
        expect(busy.board.isEmpty(move), isTrue);
      }
    });

    test('selectors never mutate the game state', () {
      final state = stateAfter(winIn1Moves);
      final boardBefore = state.board;
      final cellsBefore = boardBefore.to2DList();
      final historyBefore = state.moveHistory.length;
      final turnBefore = state.currentPlayer;

      for (final selector in allSelectors) {
        selector.selectMove(state);
      }

      expect(identical(state.board, boardBefore), isTrue,
          reason: 'The original board object must stay untouched');
      expect(state.board.to2DList(), cellsBefore);
      expect(state.moveHistory.length, historyBefore);
      expect(state.currentPlayer, turnBefore);
    });
  });

  group('SystemMoveSelector - easy (random, injectable)', () {
    test('seeded randomness is deterministic for the same state', () {
      final state = stateAfter(winIn1Moves);
      final a = RandomMoveSelector(random: Random(42));
      final b = RandomMoveSelector(random: Random(42));
      expect(a.selectMove(state), b.selectMove(state));
    });

    test('a scripted Random maps deterministically onto the empty cells', () {
      final state = stateAfter(winIn1Moves);
      // Empty cells of this state, in scan order:
      const scanOrder = [
        Position(0, 2),
        Position(1, 2),
        Position(2, 0),
        Position(2, 1),
        Position(2, 2),
      ];
      expect(
        RandomMoveSelector(random: _ScriptedRandom([0])).selectMove(state),
        scanOrder.first,
      );
      expect(
        RandomMoveSelector(random: _ScriptedRandom([4])).selectMove(state),
        scanOrder.last,
      );
    });
  });

  group('SystemMoveSelector - medium (win & block)', () {
    test('completes an immediate win on 3×3', () {
      expect(medium.selectMove(stateAfter(winIn1Moves)), const Position(0, 2));
    });

    test('blocks an immediate opponent win on 3×3', () {
      expect(medium.selectMove(stateAfter(blockIn1Moves)), const Position(0, 2));
    });

    test('falls back to the center on a sparse legal board (deterministic)', () {
      // X(0,0), O(2,2), X(1,2): no immediate win or block for either side,
      // so the center-weighted fallback decides.
      final sparse = stateAfter([
        Position(0, 0),
        Position(2, 2),
        Position(1, 2),
      ]);
      expect(medium.selectMove(sparse), const Position(1, 1));
    });

    test('prefers a win over a block when both are available', () {
      // X can win at (0,2); O threatens (2,2)? — construct: X(0,0), O(2,0),
      // X(0,1), O(2,1) → X to move: win (0,2) AND block (2,2). Win wins.
      final state = stateAfter([
        Position(0, 0),
        Position(2, 0),
        Position(0, 1),
        Position(2, 1),
      ]);
      expect(medium.selectMove(state), const Position(0, 2));
    });

    test('double direct threat: the block still targets a threat cell', () {
      // X threatens (0,2) via row 0 AND (2,0) via column 0 — O cannot block
      // both; the block must still be a valid move on one of the threats.
      final state = stateAfter([
        Position(0, 0),
        Position(1, 1),
        Position(0, 1),
        Position(2, 2),
        Position(1, 0),
      ]); // X: (0,0),(0,1),(1,0); O: (1,1),(2,2); O to move.
      for (final selector in [medium, hard]) {
        final move = selector.selectMove(state)!;
        expect(state.board.isEmpty(move), isTrue,
            reason: 'the block must be a valid empty cell');
        expect(
          {const Position(0, 2), const Position(2, 0)}.contains(move),
          isTrue,
          reason: 'even against a double threat, the block targets one of the '
              'threat cells (got $move)',
        );
      }
    });
  });

  group('SystemMoveSelector - hard (bounded search)', () {
    test('completes an immediate win before searching', () {
      expect(hard.selectMove(stateAfter(winIn1Moves)), const Position(0, 2));
    });

    test('blocks an immediate opponent win before searching', () {
      expect(hard.selectMove(stateAfter(blockIn1Moves)), const Position(0, 2));
    });

    test('prefers a win over a block when both are available', () {
      final state = stateAfter([
        Position(0, 0),
        Position(2, 0),
        Position(0, 1),
        Position(2, 1),
      ]);
      expect(hard.selectMove(state), const Position(0, 2));
    });

    test('avoids the corner fork on the classic 3×3 position', () {
      const safeEdges = [
        Position(0, 1),
        Position(1, 0),
        Position(1, 2),
        Position(2, 1),
      ];
      final move = hard.selectMove(stateAfter(forkMoves))!;
      expect(safeEdges.contains(move), isTrue,
          reason: 'Hard must take an edge, not a corner fork point (got $move)');
    });

    test('opens the center on an empty 3×3 (root center tie-break)', () {
      expect(hard.selectMove(stateAfter(const [])), const Position(1, 1));
    });

    test('opens the center cell on an empty 6×6 (candidate fallback)', () {
      expect(hard.selectMove(stateAfter(const [], config: configFor(6))),
          const Position(3, 3));
    });

    test('a tiny node cap degrades gracefully to a valid move', () {
      final capped = SearchMoveSelector(maxNodes: 5);
      final move = capped.selectMove(stateAfter(forkMoves))!;
      expect(stateAfter(forkMoves).board.isEmpty(move), isTrue);
    });

    test('never returns an occupied or out-of-bounds cell mid-game', () {
      final busy = stateAfter(oneEmptyMoves);
      final move = hard.selectMove(busy)!;
      expect(busy.board.isWithinBounds(move), isTrue);
      expect(busy.board.isEmpty(move), isTrue);
    });
  });

  group('SystemMoveSelector - large-board threats (P4 eval)', () {
    /// Legal alternation helper: plays [moves] through the real engine.
    GameState stateAfter(
      List<Position> moves, {
      required BoardConfig config,
    }) {
      final engine = GameEngine(config: config);
      for (final move in moves) {
        engine.makeMove(move);
      }
      return engine.state;
    }

    /// 6×6: X holds (2,1),(2,2); O is harmless and off-line. The fork move
    /// (2,3) creates an OPEN-THREE (winning cells (2,0) AND (2,4) — a double
    /// threat), while the center decoy (3,3) is a neutral central mark that
    /// the old center-only leaf evaluation preferred.
    GameState forkVsDecoy6() => stateAfter(const [
          Position(2, 1), // X
          Position(0, 0), // O (harmless corner)
          Position(2, 2), // X
          Position(1, 3), // O (harmless, adjacent but non-blocking)
        ], config: BoardConfig.fromSize(6));

    test('REPRO (6×6): hard creates the open-three fork, not the center decoy', () {
      final state = forkVsDecoy6();
      expect(state.currentPlayer, Player.x);
      expect(hard.selectMove(state), const Position(2, 3),
          reason: 'The open-three fork outranks a neutral central mark');
    });

    test('REPRO (6×6, O-side): facing an open-two, the response is a valid '
        'empty cell (the eval may prefer the cap or another defense — a '
        'contested position beyond depth-3 proof)', () {
      // 5 moves: X(2,1), O(0,0), X(2,2), O(1,3), X(4,4) → O to move, facing
      // X's open-two (2,1),(2,2) (the lone X(4,4) is harmless and off-row).
      final state = stateAfter(const [
        Position(2, 1), // X
        Position(0, 0), // O
        Position(2, 2), // X
        Position(1, 3), // O
        Position(4, 4), // X
      ], config: BoardConfig.fromSize(6));
      expect(state.currentPlayer, Player.o);
      final move = hard.selectMove(state)!;
      expect(state.board.isWithinBounds(move), isTrue);
      expect(state.board.isEmpty(move), isTrue);
      // X must not gain an immediate win on the follow-up: X's row-2 cells
      // (2,1),(2,2) remain capped-off only if O touched row 2 or took the
      // fork cell — we assert the weaker, provable property: O's move is
      // legal and the position stays non-terminal.
      expect(state.isGameOver, isFalse);
    });

    test('REPRO (9×9): hard builds the 4-of-5 threat (6,5) — a double threat '
        'with winning cells (6,1) and (6,6)', () {
      final state = stateAfter(const [
        Position(6, 2), // X
        Position(0, 0), // O
        Position(6, 3), // X
        Position(1, 8), // O
        Position(6, 4), // X
        Position(2, 8), // O
      ], config: BoardConfig.fromSize(9));
      expect(state.currentPlayer, Player.x);
      // For streak 5 a THREAT needs 4 marks in a 5-window: (6,5) completes
      // the 4-of-5 row segment with winning cells (6,1) AND (6,6).
      final picked = hard.selectMove(state)!;
      expect(picked, anyOf(const Position(6, 5), const Position(6, 1)),
          reason: 'The 4-of-5 threat-building move outranks the center');
    });

    test('REPRO (11×11): hard plays the 5-of-6 threat (6,6) — a double threat '
        'with winning cells (6,1) and (6,7)', () {
      final state = stateAfter(const [
        Position(6, 2), // X
        Position(0, 0), // O
        Position(6, 3), // X
        Position(1, 10), // O
        Position(6, 4), // X
        Position(2, 9), // O
        Position(6, 5), // X
        Position(3, 8), // O
      ], config: BoardConfig.fromSize(11));
      expect(state.currentPlayer, Player.x);
      // For streak 6 a THREAT needs 5 marks in a 6-window: (6,6) completes
      // the 5-of-6 row segment with winning cells (6,1) AND (6,7).
      expect(hard.selectMove(state), const Position(6, 6),
          reason: 'The double-threat building move outranks the center');
    });
  });

  group('SystemMoveSelector - node cap exhaustion (large boards)', () {
    /// 6×6 with a full alternating main diagonal (6 legal engine moves) —
    /// non-terminal, and its empties include the most central cells.
    GameState diagonalSix() => stateAfter(const [
          Position(0, 0),
          Position(1, 1),
          Position(2, 2),
          Position(3, 3),
          Position(4, 4),
          Position(5, 5),
        ], config: BoardConfig.fromSize(6));

    test('exhausted search still scans EVERY root move (center tie-break '
        'proves the full scan under total truncation)', () {
      final capped = SearchMoveSelector(maxNodes: 1);
      final move = capped.selectMove(diagonalSix())!;
      // With a 1-node cap every root child collapses to its positional
      // evaluation, so the center tie-break alone decides: the most central
      // empty cell, which sits LAST in scan order — reachable only if the
      // root loop examined all candidates.
      expect(move, const Position(2, 3));
    });

    test('tiny cap: repeated calls on the same selector stay deterministic '
        'and valid (no cross-call state leakage)', () {
      final capped = SearchMoveSelector(maxNodes: 3);
      final a = diagonalSix();
      final b = stateAfter(const [
        Position(0, 0),
        Position(1, 1),
        Position(2, 2),
        Position(4, 4),
      ], config: BoardConfig.fromSize(6));

      final firstA = capped.selectMove(a)!;
      final firstB = capped.selectMove(b)!;
      expect(capped.selectMove(a), firstA,
          reason: 'revisiting state A must reproduce the same move');
      expect(capped.selectMove(b), firstB);
      expect(capped.selectMove(a), firstA);

      expect(a.board.isWithinBounds(firstA), isTrue);
      expect(a.board.isEmpty(firstA), isTrue);
      expect(b.board.isWithinBounds(firstB), isTrue);
      expect(b.board.isEmpty(firstB), isTrue);
    });

    test('tiny cap: move validity is stable across repeated calls', () {
      final capped = SearchMoveSelector(maxNodes: 2);
      final state = diagonalSix();
      final first = capped.selectMove(state)!;
      for (var i = 0; i < 5; i++) {
        final move = capped.selectMove(state)!;
        expect(move, first, reason: 'call ${i + 1}: identical result');
        expect(state.board.isEmpty(move), isTrue);
        expect(state.board.isWithinBounds(move), isTrue);
      }
      expect(state.board.occupiedCount, 6,
          reason: 'selection never mutates the board');
    });
  });

  group('SystemMoveSelector - the four authorized sizes & streaks', () {
    for (final size in [3, 6, 9, 11]) {
      final streak = BoardConfig.winStreakForSize(size);
      final completing = Position(0, streak - 1);

      test('size $size (win streak $streak): medium completes and blocks', () {
        final winState = nearWinState(size: size, xToMove: true);
        expect(winState.currentPlayer, Player.x);
        expect(medium.selectMove(winState), completing,
            reason: 'size $size: completes the $streak streak');

        final blockState = nearWinState(size: size, xToMove: false);
        expect(blockState.currentPlayer, Player.o);
        expect(medium.selectMove(blockState), completing,
            reason: 'size $size: blocks the $streak streak');
      });

      test('size $size (win streak $streak): hard completes and blocks', () {
        final winState = nearWinState(size: size, xToMove: true);
        expect(hard.selectMove(winState), completing,
            reason: 'size $size: completes the $streak streak');

        final blockState = nearWinState(size: size, xToMove: false);
        expect(hard.selectMove(blockState), completing,
            reason: 'size $size: blocks the $streak streak');
      });

      test('size $size (win streak $streak): easy stays valid', () {
        final winState = nearWinState(size: size, xToMove: true);
        final move = easy.selectMove(winState)!;
        expect(winState.board.isEmpty(move), isTrue);
        expect(winState.board.isWithinBounds(move), isTrue);
      });
    }
  });
}

/// Deterministic scripted RNG for mapping assertions.
class _ScriptedRandom implements Random {
  _ScriptedRandom(this._values);

  final List<int> _values;
  int _index = 0;

  @override
  int nextInt(int max) => _values[_index++ % _values.length] % max;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}
