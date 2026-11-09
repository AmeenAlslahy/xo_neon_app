import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  group('GameBoard', () {
    final config = BoardConfig.classic3x3();

    test('initial empty board has all cells null and count zero', () {
      final board = GameBoard.empty(config);

      expect(board.occupiedCount, equals(0));
      expect(board.isFull, isFalse);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final pos = Position(r, c);
          expect(board.cellAt(pos), isNull);
          expect(board.isEmpty(pos), isTrue);
          expect(board.isWithinBounds(pos), isTrue);
        }
      }
    });

    test('isWithinBounds returns false for out-of-boundary positions', () {
      final board = GameBoard.empty(config);

      expect(board.isWithinBounds(const Position(-1, 0)), isFalse);
      expect(board.isWithinBounds(const Position(0, -1)), isFalse);
      expect(board.isWithinBounds(const Position(3, 0)), isFalse);
      expect(board.isWithinBounds(const Position(0, 3)), isFalse);
      expect(board.isWithinBounds(const Position(5, 5)), isFalse);
      expect(board.cellAt(const Position(9, 9)), isNull);
    });

    test('copyWithMove returns a new immutable board without mutating original', () {
      final initialBoard = GameBoard.empty(config);
      const movePos = Position(1, 1);

      final nextBoard = initialBoard.copyWithMove(movePos, Player.x);

      // Verify original board remains untouched (immutability)
      expect(initialBoard.cellAt(movePos), isNull);
      expect(initialBoard.occupiedCount, equals(0));

      // Verify new board has the player placed
      expect(nextBoard.cellAt(movePos), equals(Player.x));
      expect(nextBoard.occupiedCount, equals(1));
      expect(nextBoard.isEmpty(movePos), isFalse);
    });

    test('defensive copying protects GameBoard from external list mutations', () {
      final externalCells = List<Player?>.filled(9, null);
      final board = GameBoard.fromCells(config, externalCells);

      // Mutate external list
      externalCells[0] = Player.x;

      // Board must be completely isolated from external mutation
      expect(board.cellAt(const Position(0, 0)), isNull);
      expect(board.occupiedCount, equals(0));

      // Internal cells list must be unmodifiable
      expect(() => board.cells[0] = Player.o, throwsUnsupportedError);
    });

    test('to2DList produces strictly unmodifiable matrix', () {
      final board = GameBoard.empty(config);
      final matrix = board.to2DList();

      expect(() => matrix.add([]), throwsUnsupportedError);
      expect(() => matrix[0][0] = Player.x, throwsUnsupportedError);
    });

    test('isFull is correctly calculated when board is completely filled', () {
      var board = GameBoard.empty(BoardConfig.validated(rows: 1, cols: 1, winStreak: 1));
      expect(board.isFull, isFalse);

      board = board.copyWithMove(const Position(0, 0), Player.o);
      expect(board.isFull, isTrue);
      expect(board.occupiedCount, equals(1));
    });

    test('to2DList converts flat cells to 2D matrix accurately', () {
      var board = GameBoard.empty(config);
      board = board.copyWithMove(const Position(0, 0), Player.x);
      board = board.copyWithMove(const Position(2, 2), Player.o);

      final matrix = board.to2DList();
      expect(matrix.length, equals(3));
      expect(matrix[0].length, equals(3));
      expect(matrix[0][0], equals(Player.x));
      expect(matrix[1][1], isNull);
      expect(matrix[2][2], equals(Player.o));
    });

    test('copyWithMoveInPlace and undo mutate and restore board state efficiently', () {
      final board = GameBoard.empty(config);
      const pos = Position(1, 1);

      expect(board.occupiedCount, equals(0));
      expect(board.cellAt(pos), isNull);

      board.copyWithMoveInPlace(pos, Player.x);
      expect(board.occupiedCount, equals(1));
      expect(board.cellAt(pos), equals(Player.x));
      expect(board.rawCellAtIndex(4), equals(1)); // 1*3 + 1 = 4

      board.undo(pos);
      expect(board.occupiedCount, equals(0));
      expect(board.cellAt(pos), isNull);
      expect(board.rawCellAtIndex(4), equals(0));
    });

    test('copyWithMoveIndexInPlace and undoIndex work with flat indices', () {
      final board = GameBoard.empty(config);
      const idx = 2; // (0, 2)

      board.copyWithMoveIndexInPlace(idx, Player.o);
      expect(board.occupiedCount, equals(1));
      expect(board.cellAtIndex(idx), equals(Player.o));
      expect(board.cellAt(const Position(0, 2)), equals(Player.o));

      board.undoIndex(idx);
      expect(board.occupiedCount, equals(0));
      expect(board.cellAtIndex(idx), isNull);
      expect(board.cellAt(const Position(0, 2)), isNull);
    });
  });
}
