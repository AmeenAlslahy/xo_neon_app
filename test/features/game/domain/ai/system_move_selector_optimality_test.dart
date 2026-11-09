import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

/// Exhaustive verification of the "optimal on 3×3" claim for the hard
/// selector.
///
/// Reference: a plain full minimax written HERE (no alpha-beta, no pruning,
/// no node cap) — independent of the search under test. The only shared
/// component is WinEvaluator, i.e. the game's own win rules.
///
/// Sweep: every REACHABLE non-terminal legal 3×3 position (legal turn
/// alternation from the empty board, stopping at wins/draws), for BOTH play
/// sides, with the DEFAULT node cap in effect. The assertion: the hard
/// selector's chosen cell must achieve the position's game-theoretic value
/// (it is in the reference's optimal-move set).
void main() {
  final hard = SearchMoveSelector();
  final reference = _ReferenceSolver();

  String pattern(GameBoard board) =>
      board.cells.map((p) => p?.symbol ?? '.').join();

  test(
    'hard plays optimally on every reachable 3×3 position (both sides, default node cap)',
    () {
      final failures = <String>[];
      final uniquePatterns = <String>{};
      var positionsChecked = 0;
      var xToMoveCount = 0;
      var oToMoveCount = 0;

      void dfs(GameBoard board, Player mover) {
        positionsChecked++;
        uniquePatterns.add(pattern(board));
        if (mover == Player.x) {
          xToMoveCount++;
        } else {
          oToMoveCount++;
        }

        final state = GameState(
          config: board.config,
          board: board,
          startingPlayer: Player.x,
          currentPlayer: mover,
          status: GameInProgress(mover),
          moveHistory: const [],
        );
        final chosen = hard.selectMove(state);
        if (chosen == null && failures.length < 20) {
          failures.add(
            'null selection at ${pattern(board)} (${mover.symbol} to move)',
          );
        } else {
          final optimal = reference.optimalCells(board, mover);
          if (!optimal.contains(chosen) && failures.length < 20) {
            failures.add(
              'suboptimal at ${pattern(board)} (${mover.symbol} to move): '
              'chose $chosen, '
              'optimal=${optimal.map((p) => '(${'$p'})').toList()}',
            );
          }
        }

        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 3; c++) {
            final p = Position(r, c);
            if (!board.isEmpty(p)) {
              continue;
            }
            final next = board.copyWithMove(p, mover);
            final terminal = reference.isTerminalAfter(next, p, mover);
            if (terminal) {
              continue; // game ended here — no deeper legal positions
            }
            dfs(next, mover.other);
          }
        }
      }

      dfs(GameBoard.empty(BoardConfig.grid3x3), Player.x);

      // ignore: avoid_print
      print('exhaustive 3×3 sweep: treeVisits=$positionsChecked '
          'uniqueStates=${uniquePatterns.length} '
          'xToMove=$xToMoveCount oToMove=$oToMoveCount '
          'failures=${failures.length}');
      expect(xToMoveCount, greaterThan(0), reason: 'X-to-move positions covered');
      expect(oToMoveCount, greaterThan(0), reason: 'O-to-move positions covered');
      expect(positionsChecked, greaterThan(1000),
          reason: 'the sweep must cover the reachable 3×3 positions');
      expect(failures, isEmpty,
          reason: 'suboptimal choices: ${failures.take(5)}');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Independent reference: plain full minimax for 3×3 (memoized on the board
/// pattern). Values are from the mover's perspective: +1 win, 0 draw, −1 loss.
class _ReferenceSolver {
  final Map<String, int> _values = {};
  final WinEvaluator _evaluator = const WinEvaluator();

  bool isTerminalAfter(GameBoard board, Position lastMove, Player mover) =>
      _evaluator.checkWinFromMove(
            board: board,
            lastMove: lastMove,
            player: mover,
          ) !=
          null ||
      board.isFull;

  int? bestValue(GameBoard board, Player mover) {
    final key = '${mover.symbol}:${board.cells.map((p) => p?.symbol ?? '.').join()}';
    final cached = _values[key];
    if (cached != null) {
      return cached;
    }

    var best = -2;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final p = Position(r, c);
        if (!board.isEmpty(p)) {
          continue;
        }
        final next = board.copyWithMove(p, mover);
        int value;
        if (_evaluator.checkWinFromMove(
              board: next,
              lastMove: p,
              player: mover,
            ) !=
            null) {
          value = 1;
        } else if (next.isFull) {
          value = 0;
        } else {
          value = -bestValue(next, mover.other)!;
        }
        if (value > best) {
          best = value;
        }
      }
    }
    _values[key] = best;
    return best;
  }

  /// All cells whose play achieves the position's best game value.
  Set<Position> optimalCells(GameBoard board, Player mover) {    final result = <Position>{};
    var best = -2;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final p = Position(r, c);
        if (!board.isEmpty(p)) {
          continue;
        }
        final next = board.copyWithMove(p, mover);
        int value;
        if (_evaluator.checkWinFromMove(
              board: next,
              lastMove: p,
              player: mover,
            ) !=
            null) {
          value = 1;
        } else if (next.isFull) {
          value = 0;
        } else {
          value = -bestValue(next, mover.other)!;
        }
        if (value > best) {
          best = value;
          result.clear();
        }
        if (value == best) {
          result.add(p);
        }
      }
    }
    return result;
  }
}
