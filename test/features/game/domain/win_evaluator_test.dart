import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  const evaluator = WinEvaluator();

  group('WinEvaluator', () {
    // ==========================================
    // 1. 3x3 Classic Grid (winStreak = 3)
    // ==========================================
    group('3x3 Classic Grid (WinStreak = 3)', () {
      final config = BoardConfig.grid3x3;

      test('detects Horizontal win across all rows for Player X', () {
        for (var row = 0; row < 3; row++) {
          var board = GameBoard.empty(config);
          board = board.copyWithMove(Position(row, 0), Player.x);
          board = board.copyWithMove(Position(row, 1), Player.x);
          board = board.copyWithMove(Position(row, 2), Player.x);

          final line = evaluator.checkWinFromMove(
            board: board,
            lastMove: Position(row, 2),
            player: Player.x,
          );

          expect(line, isNotNull, reason: 'Failed for row $row');
          expect(line!.direction, equals(WinDirection.horizontal));
          expect(line.length, equals(3));
          expect(line.start, equals(Position(row, 0)));
          expect(line.end, equals(Position(row, 2)));
        }
      });

      test('detects Vertical win across all columns for Player O', () {
        for (var col = 0; col < 3; col++) {
          var board = GameBoard.empty(config);
          board = board.copyWithMove(Position(0, col), Player.o);
          board = board.copyWithMove(Position(1, col), Player.o);
          board = board.copyWithMove(Position(2, col), Player.o);

          final line = evaluator.checkWinFromMove(
            board: board,
            lastMove: Position(1, col), // Triggered from center of column
            player: Player.o,
          );

          expect(line, isNotNull, reason: 'Failed for col $col');
          expect(line!.direction, equals(WinDirection.vertical));
          expect(line.length, equals(3));
          expect(line.start, equals(Position(0, col)));
          expect(line.end, equals(Position(2, col)));
        }
      });

      test('detects Main Diagonal (\\) win from top-left to bottom-right', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 0), Player.x);
        board = board.copyWithMove(const Position(1, 1), Player.x);
        board = board.copyWithMove(const Position(2, 2), Player.x);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(1, 1),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.diagonal));
        expect(line.length, equals(3));
        expect(line.start, equals(const Position(0, 0)));
        expect(line.end, equals(const Position(2, 2)));
      });

      test('detects Anti-Diagonal (/) win from top-right to bottom-left', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 2), Player.o);
        board = board.copyWithMove(const Position(1, 1), Player.o);
        board = board.copyWithMove(const Position(2, 0), Player.o);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(2, 0),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.antiDiagonal));
        expect(line.length, equals(3));
        expect(line.start, equals(const Position(0, 2)));
        expect(line.end, equals(const Position(2, 0)));
      });

      test('does NOT declare win when only 2 consecutive marks are placed', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 0), Player.x);
        board = board.copyWithMove(const Position(0, 1), Player.x);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(0, 1),
          player: Player.x,
        );

        expect(line, isNull);
      });

      test('does NOT declare win when gap exists between marks', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 0), Player.x);
        // Position (0, 1) is empty
        board = board.copyWithMove(const Position(0, 2), Player.x);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(0, 2),
          player: Player.x,
        );

        expect(line, isNull);
      });

      test('does NOT declare win when opponent mark interrupts sequence', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 0), Player.x);
        board = board.copyWithMove(const Position(0, 1), Player.o); // Opponent mark
        board = board.copyWithMove(const Position(0, 2), Player.x);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(0, 2),
          player: Player.x,
        );

        expect(line, isNull);
      });

      test('deterministic evaluation of multiple simultaneous winning lines', () {
        // Center '+' intersection win at (1, 1):
        // . X .
        // X X X  <- Horizontal & Vertical
        // . X .
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 1), Player.x);
        board = board.copyWithMove(const Position(2, 1), Player.x);
        board = board.copyWithMove(const Position(1, 0), Player.x);
        board = board.copyWithMove(const Position(1, 2), Player.x);
        board = board.copyWithMove(const Position(1, 1), Player.x); // Completes both!

        final lines = evaluator.findAllWinningLinesFromMove(
          board: board,
          lastMove: const Position(1, 1),
          player: Player.x,
        );

        expect(lines.length, equals(2));
        // Deterministic order: Horizontal first, then Vertical
        expect(lines[0].direction, equals(WinDirection.horizontal));
        expect(lines[1].direction, equals(WinDirection.vertical));
      });
    });

    // ==========================================
    // 2. 6x6 Tactical Grid (winStreak = 4)
    // ==========================================
    group('6x6 Tactical Grid (WinStreak = 4)', () {
      final config = BoardConfig.grid6x6;

      test('detects Horizontal 4-in-a-row for Player X', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(2, 1), Player.x);
        board = board.copyWithMove(const Position(2, 2), Player.x);
        board = board.copyWithMove(const Position(2, 3), Player.x);
        board = board.copyWithMove(const Position(2, 4), Player.x);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(2, 4),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.horizontal));
        expect(line.length, equals(4));
        expect(line.start, equals(const Position(2, 1)));
        expect(line.end, equals(const Position(2, 4)));
      });

      test('detects Vertical 4-in-a-row for Player O near right border', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(1, 5), Player.o);
        board = board.copyWithMove(const Position(2, 5), Player.o);
        board = board.copyWithMove(const Position(3, 5), Player.o);
        board = board.copyWithMove(const Position(4, 5), Player.o);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(1, 5),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.vertical));
        expect(line.length, equals(4));
        expect(line.start, equals(const Position(1, 5)));
        expect(line.end, equals(const Position(4, 5)));
      });

      test('detects Diagonal (\\) 4-in-a-row near corner', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 0), Player.x);
        board = board.copyWithMove(const Position(1, 1), Player.x);
        board = board.copyWithMove(const Position(2, 2), Player.x);
        board = board.copyWithMove(const Position(3, 3), Player.x);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(0, 0),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.diagonal));
        expect(line.length, equals(4));
        expect(line.start, equals(const Position(0, 0)));
        expect(line.end, equals(const Position(3, 3)));
      });

      test('detects Anti-Diagonal (/) 4-in-a-row in center', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(1, 4), Player.o);
        board = board.copyWithMove(const Position(2, 3), Player.o);
        board = board.copyWithMove(const Position(3, 2), Player.o);
        board = board.copyWithMove(const Position(4, 1), Player.o);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(3, 2),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.antiDiagonal));
        expect(line.length, equals(4));
        expect(line.start, equals(const Position(1, 4)));
        expect(line.end, equals(const Position(4, 1)));
      });

      test('3 consecutive marks in 6x6 does NOT count as win', () {
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 0), Player.x);
        board = board.copyWithMove(const Position(0, 1), Player.x);
        board = board.copyWithMove(const Position(0, 2), Player.x);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(0, 2),
          player: Player.x,
        );

        expect(line, isNull);
      });

      test('detects win when sequence EXCEEDS required win streak (5 in 4-mode)', () {
        var board = GameBoard.empty(config);
        for (var c = 0; c < 5; c++) {
          board = board.copyWithMove(Position(3, c), Player.x);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(3, 2),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.length, equals(5)); // captures all 5 continuous marks
      });
    });

    // ==========================================
    // 3. 9x9 Pro Grid (winStreak = 5)
    // ==========================================
    group('9x9 Pro Grid (WinStreak = 5)', () {
      final config = BoardConfig.grid9x9;

      test('detects 5-in-a-row Horizontal win for Player O', () {
        var board = GameBoard.empty(config);
        for (var c = 2; c <= 6; c++) {
          board = board.copyWithMove(Position(4, c), Player.o);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(4, 4),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.horizontal));
        expect(line.length, equals(5));
        expect(line.start, equals(const Position(4, 2)));
        expect(line.end, equals(const Position(4, 6)));
      });

      test('detects 5-in-a-row Vertical win near bottom border for Player X', () {
        var board = GameBoard.empty(config);
        for (var r = 4; r <= 8; r++) {
          board = board.copyWithMove(Position(r, 7), Player.x);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(8, 7),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.vertical));
        expect(line.length, equals(5));
        expect(line.start, equals(const Position(4, 7)));
        expect(line.end, equals(const Position(8, 7)));
      });

      test('detects 5-in-a-row Diagonal (\\) win', () {
        var board = GameBoard.empty(config);
        for (var i = 1; i <= 5; i++) {
          board = board.copyWithMove(Position(i, i), Player.x);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(3, 3),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.diagonal));
        expect(line.length, equals(5));
      });

      test('detects 5-in-a-row Anti-Diagonal (/) win', () {
        var board = GameBoard.empty(config);
        // (2, 6), (3, 5), (4, 4), (5, 3), (6, 2)
        board = board.copyWithMove(const Position(2, 6), Player.o);
        board = board.copyWithMove(const Position(3, 5), Player.o);
        board = board.copyWithMove(const Position(4, 4), Player.o);
        board = board.copyWithMove(const Position(5, 3), Player.o);
        board = board.copyWithMove(const Position(6, 2), Player.o);

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(4, 4),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.antiDiagonal));
        expect(line.length, equals(5));
      });

      test('4 marks in 9x9 does NOT count as win', () {
        var board = GameBoard.empty(config);
        for (var c = 0; c < 4; c++) {
          board = board.copyWithMove(Position(0, c), Player.x);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(0, 3),
          player: Player.x,
        );

        expect(line, isNull);
      });
    });

    // ==========================================
    // 4. 11x11 Master Grid (winStreak = 6)
    // ==========================================
    group('11x11 Master Grid (WinStreak = 6)', () {
      final config = BoardConfig.grid11x11;

      test('detects 6-in-a-row Horizontal win for Player X at top border', () {
        var board = GameBoard.empty(config);
        for (var c = 3; c <= 8; c++) {
          board = board.copyWithMove(Position(0, c), Player.x);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(0, 8),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.horizontal));
        expect(line.length, equals(6));
        expect(line.start, equals(const Position(0, 3)));
        expect(line.end, equals(const Position(0, 8)));
      });

      test('detects 6-in-a-row Vertical win for Player O at column 10 (edge)', () {
        var board = GameBoard.empty(config);
        for (var r = 5; r <= 10; r++) {
          board = board.copyWithMove(Position(r, 10), Player.o);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(10, 10),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.vertical));
        expect(line.length, equals(6));
        expect(line.start, equals(const Position(5, 10)));
        expect(line.end, equals(const Position(10, 10)));
      });

      test('detects 6-in-a-row Diagonal (\\) win', () {
        var board = GameBoard.empty(config);
        for (var i = 2; i <= 7; i++) {
          board = board.copyWithMove(Position(i, i), Player.x);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(5, 5),
          player: Player.x,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.diagonal));
        expect(line.length, equals(6));
        expect(line.start, equals(const Position(2, 2)));
        expect(line.end, equals(const Position(7, 7)));
      });

      test('detects 6-in-a-row Anti-Diagonal (/) win', () {
        var board = GameBoard.empty(config);
        // From (3, 8) to (8, 3)
        for (var i = 0; i < 6; i++) {
          board = board.copyWithMove(Position(3 + i, 8 - i), Player.o);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(5, 6),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.direction, equals(WinDirection.antiDiagonal));
        expect(line.length, equals(6));
        expect(line.start, equals(const Position(3, 8)));
        expect(line.end, equals(const Position(8, 3)));
      });

      test('5 marks in 11x11 does NOT count as win (needs 6)', () {
        var board = GameBoard.empty(config);
        for (var c = 0; c < 5; c++) {
          board = board.copyWithMove(Position(5, c), Player.x);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(5, 4),
          player: Player.x,
        );

        expect(line, isNull);
      });

      test('7 marks in a row in 11x11 satisfies and detects entire streak', () {
        var board = GameBoard.empty(config);
        for (var c = 2; c <= 8; c++) {
          board = board.copyWithMove(Position(1, c), Player.o);
        }

        final line = evaluator.checkWinFromMove(
          board: board,
          lastMove: const Position(1, 5),
          player: Player.o,
        );

        expect(line, isNotNull);
        expect(line!.length, equals(7));
      });
    });

    // ==========================================
    // 5. Full Board Scan
    // ==========================================
    group('Full Board Scan', () {
      test('scanBoardForWin finds existing win on arbitrary board state', () {
        final config = BoardConfig.grid3x3;
        var board = GameBoard.empty(config);
        board = board.copyWithMove(const Position(0, 0), Player.x);
        board = board.copyWithMove(const Position(1, 1), Player.x);
        board = board.copyWithMove(const Position(2, 2), Player.x);

        final detected = evaluator.scanBoardForWin(
          board: board,
          player: Player.x,
        );

        expect(detected, isNotNull);
        expect(detected!.direction, equals(WinDirection.diagonal));
      });
    });
  });
}
