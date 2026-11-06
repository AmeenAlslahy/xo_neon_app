import '../models/cell_position.dart';
import '../models/player.dart';
import '../models/winning_line.dart';
import 'game_board.dart';

/// Pure logic utility to evaluate win conditions on any board configuration.
class WinEvaluator {
  const WinEvaluator();

  /// Direction vectors evaluated in deterministic order:
  /// 1. Horizontal
  /// 2. Vertical
  /// 3. Diagonal (\)
  /// 4. Anti-Diagonal (/)
  static const List<(int, int, WinDirection)> directions = [
    (0, 1, WinDirection.horizontal),
    (1, 0, WinDirection.vertical),
    (1, 1, WinDirection.diagonal),
    (1, -1, WinDirection.antiDiagonal),
  ];

  /// Finds all winning lines passing through [lastMove] for [player].
  ///
  /// When a single placement simultaneously forms multiple winning streaks
  /// (e.g., an intersection between a row and column), all are detected
  /// and returned in deterministic order.
  List<WinningLine> findAllWinningLinesFromMove({
    required GameBoard board,
    required Position lastMove,
    required Player player,
  }) {
    final winStreak = board.config.winStreak;

    // Special fast-path for 1x1 wacky mode with winStreak == 1
    if (winStreak == 1) {
      if (board.cellAt(lastMove) == player) {
        return [
          WinningLine(
            positions: [lastMove],
            direction: WinDirection.horizontal,
          ),
        ];
      }
      return const [];
    }

    final winningLines = <WinningLine>[];

    for (final (dr, dc, dirEnum) in directions) {
      final contiguousPositions = _collectContiguousLine(
        board: board,
        center: lastMove,
        player: player,
        dr: dr,
        dc: dc,
      );

      if (contiguousPositions.length >= winStreak) {
        winningLines.add(
          WinningLine(
            positions: contiguousPositions,
            direction: dirEnum,
          ),
        );
      }
    }

    return List.unmodifiable(winningLines);
  }

  /// Evaluates whether placing a move at [lastMove] by [player] created a win.
  /// Returns the primary detected [WinningLine] (the first in deterministic order), or null.
  WinningLine? checkWinFromMove({
    required GameBoard board,
    required Position lastMove,
    required Player player,
  }) {
    final lines = findAllWinningLinesFromMove(
      board: board,
      lastMove: lastMove,
      player: player,
    );
    return lines.isEmpty ? null : lines.first;
  }

  /// Scans the entire board to detect any winning sequence for [player].
  /// Useful for comprehensive audits or evaluating arbitrary board states.
  WinningLine? scanBoardForWin({
    required GameBoard board,
    required Player player,
  }) {
    for (var r = 0; r < board.config.rows; r++) {
      for (var c = 0; c < board.config.cols; c++) {
        final pos = Position(r, c);
        if (board.cellAt(pos) == player) {
          final line = checkWinFromMove(
            board: board,
            lastMove: pos,
            player: player,
          );
          if (line != null) return line;
        }
      }
    }
    return null;
  }

  /// Collects all consecutive matching cells through [center] along (dr, dc),
  /// sorted from one end to the other.
  List<Position> _collectContiguousLine({
    required GameBoard board,
    required Position center,
    required Player player,
    required int dr,
    required int dc,
  }) {
    final backwards = <Position>[];
    var r = center.row - dr;
    var c = center.col - dc;
    while (board.isWithinBounds(Position(r, c)) &&
        board.cellAt(Position(r, c)) == player) {
      backwards.add(Position(r, c));
      r -= dr;
      c -= dc;
    }

    final forwards = <Position>[];
    r = center.row + dr;
    c = center.col + dc;
    while (board.isWithinBounds(Position(r, c)) &&
        board.cellAt(Position(r, c)) == player) {
      forwards.add(Position(r, c));
      r += dr;
      c += dc;
    }

    // Combine in natural sequence: [furthest backward ... center ... furthest forward]
    return [
      ...backwards.reversed,
      center,
      ...forwards,
    ];
  }
}
