import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

/// Deterministic large-board scenarios. These are deliberately built from
/// snapshots (not random play) so the same failure cannot be hidden by a
/// different opening or a lucky reply.
void main() {
  final hard = SearchMoveSelector();

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

  GameState apply(GameState state, Position position) =>
      GameEngine.applyMove(currentState: state, position: position);

  /// Every empty cell where [player] would win immediately on the next move.
  List<Position> immediateWinningCells(GameBoard board, Player player) {
    final result = <Position>[];
    for (var r = 0; r < board.config.rows; r++) {
      for (var c = 0; c < board.config.cols; c++) {
        final position = Position(r, c);
        if (!board.isEmpty(position)) {
          continue;
        }
        final simulated = board.copyWithMove(position, player);
        if (const WinEvaluator().checkWinFromMove(
              board: simulated,
              lastMove: position,
              player: player,
            ) !=
            null) {
          result.add(position);
        }
      }
    }
    return result;
  }

  /// A purely local candidate set cannot reach these cells after a corner
  /// opening. They are the central band for each authorized size.
  List<Position> centralBand(BoardConfig config) {
    final bandSize = config.rows <= 6 ? 2 : 3;
    final startRow = (config.rows - bandSize) ~/ 2;
    final startCol = (config.cols - bandSize) ~/ 2;
    return [
      for (var r = startRow; r < startRow + bandSize; r++)
        for (var c = startCol; c < startCol + bandSize; c++)
          Position(r, c),
    ];
  }

  void expectNoDoubleThreatAfterExtension({
    required GameState afterSystemMove,
    required List<Position> extensions,
    required Player opponent,
  }) {
    for (final extension in extensions) {
      if (!afterSystemMove.board.isEmpty(extension)) {
        continue;
      }
      final afterOpponent = apply(afterSystemMove, extension);
      expect(afterOpponent.isGameOver, isFalse,
          reason: 'The opponent must not win immediately at $extension');
      final winningCells =
          immediateWinningCells(afterOpponent.board, opponent);
      expect(
        winningCells.length,
        lessThanOrEqualTo(1),
        reason: 'At $extension the opponent created a double threat: '
            '$winningCells',
      );
    }
  }

  group('large-board proactive defense', () {
    test('6×6 blocks an open two before it becomes an open three', () {
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

      final move = hard.selectMove(state);
      expect(move, isNotNull);
      expect(
        move,
        anyOf(const Position(2, 1), const Position(2, 4)),
        reason: 'X must close one end of O\'s open two',
      );

      final afterSystem = apply(state, move!);
      expect(afterSystem.isGameOver, isFalse);
      expectNoDoubleThreatAfterExtension(
        afterSystemMove: afterSystem,
        extensions: const [Position(2, 1), Position(2, 4)],
        opponent: Player.o,
      );
    });

    test('9×9 blocks an open three before it becomes an open four', () {
      final state = stateWith(
        config: BoardConfig.grid9x9,
        stones: {
          const Position(4, 3): Player.o,
          const Position(4, 4): Player.o,
          const Position(4, 5): Player.o,
          const Position(8, 0): Player.x,
          const Position(8, 1): Player.x,
          const Position(8, 2): Player.x,
        },
        turn: Player.x,
      );

      final move = hard.selectMove(state);
      expect(move, isNotNull);
      expect(
        move,
        anyOf(const Position(4, 2), const Position(4, 6)),
        reason: 'X must close one end of O\'s open three',
      );

      final afterSystem = apply(state, move!);
      expect(afterSystem.isGameOver, isFalse);
      expectNoDoubleThreatAfterExtension(
        afterSystemMove: afterSystem,
        extensions: const [Position(4, 2), Position(4, 6)],
        opponent: Player.o,
      );
    });

    test('11×11 blocks an open four before it becomes an open five', () {
      final state = stateWith(
        config: BoardConfig.grid11x11,
        stones: {
          const Position(5, 3): Player.o,
          const Position(5, 4): Player.o,
          const Position(5, 5): Player.o,
          const Position(5, 6): Player.o,
          const Position(10, 0): Player.x,
          const Position(10, 1): Player.x,
          const Position(10, 2): Player.x,
          const Position(10, 3): Player.x,
        },
        turn: Player.x,
      );

      final move = hard.selectMove(state);
      expect(move, isNotNull);
      expect(
        move,
        anyOf(const Position(5, 2), const Position(5, 7)),
        reason: 'X must close one end of O\'s open four',
      );

      final afterSystem = apply(state, move!);
      expect(afterSystem.isGameOver, isFalse);
      expectNoDoubleThreatAfterExtension(
        afterSystemMove: afterSystem,
        extensions: const [Position(5, 2), Position(5, 7)],
        opponent: Player.o,
      );
    });
  });

  group('large-board opening', () {
    test('after a corner move, the reply contests the central band', () {
      for (final size in [6, 9, 11]) {
        final config = BoardConfig.fromSize(size);
        final state = stateWith(
          config: config,
          stones: {const Position(0, 0): Player.x},
          turn: Player.o,
        );
        final move = hard.selectMove(state);
        expect(move, isNotNull, reason: 'size $size: opening reply exists');
        expect(
          centralBand(config),
          contains(move),
          reason: 'size $size: a local corner reply concedes the center; '
              'chosen $move',
        );
      }
    });

    test('after a center move, the reply stays near the center', () {
      for (final size in [6, 9, 11]) {
        final config = BoardConfig.fromSize(size);
        final center = Position(config.rows ~/ 2, config.cols ~/ 2);
        final state = stateWith(
          config: config,
          stones: {center: Player.x},
          turn: Player.o,
        );
        final move = hard.selectMove(state);
        expect(move, isNotNull, reason: 'size $size: reply exists');
        expect(state.board.isEmpty(move!), isTrue,
            reason: 'size $size: the reply must be legal');
        expect(
          (move.row - center.row).abs() <= 1 &&
              (move.col - center.col).abs() <= 1,
          isTrue,
          reason: 'size $size: the reply must contest the center, got $move',
        );
      }
    });
  });

  group('large-board attack priority', () {
    test('6×6 takes its own immediate win instead of blocking the opponent',
        () {
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

      expect(hard.selectMove(state), const Position(2, 3),
          reason: 'Winning now is better than blocking O at (4,3)');
    });
  });
}
