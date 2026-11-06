import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  group('GameEngine', () {
    final fixedTime = DateTime(2026, 11, 6, 12, 0, 0);

    group('Pure Functional State Transition (applyMove)', () {
      test('applyMove is pure, deterministic, and returns a new GameState without mutating input', () {
        final config = BoardConfig.classic3x3();
        final initialState = GameState.initial(config: config);

        final nextState = GameEngine.applyMove(
          currentState: initialState,
          position: const Position(1, 1),
          timestamp: fixedTime,
        );

        // Verify initial state is completely untouched
        expect(initialState.board.occupiedCount, equals(0));
        expect(initialState.moveHistory, isEmpty);
        expect(initialState.currentPlayer, equals(Player.x));

        // Verify next state is properly updated
        expect(nextState.board.occupiedCount, equals(1));
        expect(nextState.board.cellAt(const Position(1, 1)), equals(Player.x));
        expect(nextState.currentPlayer, equals(Player.o));
        expect(nextState.moveHistory.first.timestamp, equals(fixedTime));
      });
    });

    group('Initial State & Deterministic Clock Injection', () {
      test('initializes with default starting player X and empty board', () {
        final engine = GameEngine(
          config: BoardConfig.classic3x3(),
          clock: () => fixedTime,
        );

        expect(engine.currentPlayer, equals(Player.x));
        expect(engine.startingPlayer, equals(Player.x));
        expect(engine.isGameOver, isFalse);
        expect(engine.status, equals(const GameInProgress(Player.x)));
        expect(engine.board.occupiedCount, equals(0));
        expect(engine.moveHistory, isEmpty);
      });

      test('uses injected clock for recorded moves', () {
        final engine = GameEngine(
          config: BoardConfig.classic3x3(),
          clock: () => fixedTime,
        );

        engine.makeMove(const Position(0, 0));
        expect(engine.moveHistory.first.timestamp, equals(fixedTime));
      });

      test('allows configuring custom starting player O', () {
        final engine = GameEngine(
          config: BoardConfig.classic3x3(),
          startingPlayer: Player.o,
        );

        expect(engine.currentPlayer, equals(Player.o));
        expect(engine.startingPlayer, equals(Player.o));
        expect(engine.status, equals(const GameInProgress(Player.o)));
      });
    });

    group('Turn Progression & Move Execution', () {
      test('alternates turn between X and O on consecutive moves', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        engine.makeMove(const Position(0, 0));
        expect(engine.currentPlayer, equals(Player.o));
        expect(engine.board.cellAt(const Position(0, 0)), equals(Player.x));
        expect(engine.moveHistory.length, equals(1));

        engine.makeMove(const Position(0, 1));
        expect(engine.currentPlayer, equals(Player.x));
        expect(engine.board.cellAt(const Position(0, 1)), equals(Player.o));
        expect(engine.moveHistory.length, equals(2));
      });

      test('records move history with sequential 1-based move numbers', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());
        engine.makeMove(const Position(1, 1));
        engine.makeMove(const Position(0, 0));

        final moves = engine.moveHistory;
        expect(moves[0].moveNumber, equals(1));
        expect(moves[0].player, equals(Player.x));
        expect(moves[0].position, equals(const Position(1, 1)));

        expect(moves[1].moveNumber, equals(2));
        expect(moves[1].player, equals(Player.o));
        expect(moves[1].position, equals(const Position(0, 0)));
      });
    });

    group('Invalid Move Violations & Exception Handling', () {
      test('throws OutOfBoundsException when coordinates are outside the grid', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        expect(
          () => engine.makeMove(const Position(-1, 0)),
          throwsA(isA<OutOfBoundsException>()),
        );
        expect(
          () => engine.makeMove(const Position(0, 3)),
          throwsA(isA<OutOfBoundsException>()),
        );
        expect(
          () => engine.makeMove(const Position(5, 5)),
          throwsA(isA<OutOfBoundsException>()),
        );
      });

      test('throws CellAlreadyOccupiedException when moving into a non-empty cell', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());
        engine.makeMove(const Position(1, 1)); // X plays center

        expect(
          () => engine.makeMove(const Position(1, 1)), // O attempts same cell
          throwsA(
            isA<CellAlreadyOccupiedException>().having(
              (e) => e.existingPlayer,
              'existingPlayer',
              equals(Player.x),
            ),
          ),
        );
      });

      test('throws WrongTurnException if explicit player does not match turn', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        // Currently Player.x's turn. Player.o attempts to play.
        expect(
          () => engine.makeMove(const Position(0, 0), player: Player.o),
          throwsA(
            isA<WrongTurnException>().having(
              (e) => e.attemptedPlayer,
              'attemptedPlayer',
              equals(Player.o),
            ),
          ),
        );
      });

      test('throws GameOverException when moving after game has ended in victory', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        // X wins on row 0:
        engine.makeMove(const Position(0, 0)); // X
        engine.makeMove(const Position(1, 0)); // O
        engine.makeMove(const Position(0, 1)); // X
        engine.makeMove(const Position(1, 1)); // O
        engine.makeMove(const Position(0, 2)); // X wins!

        expect(engine.isGameOver, isTrue);
        expect(engine.winner, equals(Player.x));

        // Any subsequent move must be blocked
        expect(
          () => engine.makeMove(const Position(2, 2)),
          throwsA(isA<GameOverException>()),
        );
      });

      test('throws GameOverException when moving after game has ended in DRAW', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        // Play to a draw
        final moves = [
          const Position(0, 0), // X
          const Position(0, 1), // O
          const Position(0, 2), // X
          const Position(1, 2), // O
          const Position(1, 0), // X
          const Position(2, 0), // O
          const Position(1, 1), // X
          const Position(2, 2), // O
          const Position(2, 1), // X (completes draw)
        ];

        for (final m in moves) {
          engine.makeMove(m);
        }

        expect(engine.isDraw, isTrue);
        expect(engine.isGameOver, isTrue);

        // Attempting to move after draw must throw GameOverException
        expect(
          () => engine.makeMove(const Position(0, 0)),
          throwsA(isA<GameOverException>()),
        );
      });
    });

    group('Victory Scenarios & Multiple Winning Lines', () {
      test('complete match ending in Player X victory', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        // Moves:
        // X: (0,0), O: (0,1)
        // X: (1,1), O: (0,2)
        // X: (2,2) -> Diagonal Win for X
        engine.makeMove(const Position(0, 0));
        engine.makeMove(const Position(0, 1));
        engine.makeMove(const Position(1, 1));
        engine.makeMove(const Position(0, 2));
        final state = engine.makeMove(const Position(2, 2));

        expect(state.isGameOver, isTrue);
        expect(state.isWon, isTrue);
        expect(state.winner, equals(Player.x));
        expect(state.winningLine, isNotNull);
        expect(state.winningLine!.direction, equals(WinDirection.diagonal));
      });

      test('complete match ending in Player O victory', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        // Moves:
        // X: (0,0), O: (1,0)
        // X: (0,1), O: (1,1)
        // X: (2,2), O: (1,2) -> Horizontal Win for O on row 1
        engine.makeMove(const Position(0, 0));
        engine.makeMove(const Position(1, 0));
        engine.makeMove(const Position(0, 1));
        engine.makeMove(const Position(1, 1));
        engine.makeMove(const Position(2, 2));
        final state = engine.makeMove(const Position(1, 2));

        expect(state.isGameOver, isTrue);
        expect(state.isWon, isTrue);
        expect(state.winner, equals(Player.o));
        expect(state.winningLine!.direction, equals(WinDirection.horizontal));
      });

      test('handles simultaneous multiple winning lines and exposes all lines', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        // Set up cross for X:
        // . X .
        // X X X
        // . X .
        engine.makeMove(const Position(0, 1)); // X
        engine.makeMove(const Position(0, 0)); // O
        engine.makeMove(const Position(2, 1)); // X
        engine.makeMove(const Position(0, 2)); // O
        engine.makeMove(const Position(1, 0)); // X
        engine.makeMove(const Position(2, 0)); // O
        engine.makeMove(const Position(1, 2)); // X
        engine.makeMove(const Position(2, 2)); // O

        // Move 9 at (1, 1) by X completes BOTH row 1 and col 1!
        final state = engine.makeMove(const Position(1, 1));

        expect(state.isWon, isTrue);
        expect(state.winner, equals(Player.x));
        expect(engine.allWinningLines, isNotNull);
        expect(engine.allWinningLines!.length, equals(2));
        expect(engine.allWinningLines![0].direction, equals(WinDirection.horizontal));
        expect(engine.allWinningLines![1].direction, equals(WinDirection.vertical));
        // Primary winning line is the first
        expect(engine.winningLine, equals(engine.allWinningLines![0]));
      });

      test('1x1 wacky mode ends on the very first move', () {
        final engine = GameEngine(config: BoardConfig.validated(rows: 1, cols: 1, winStreak: 1));
        final state = engine.makeMove(const Position(0, 0));

        expect(state.isGameOver, isTrue);
        expect(state.winner, equals(Player.x));
        expect(state.winningLine!.length, equals(1));

        // Subsequent move is rejected
        expect(
          () => engine.makeMove(const Position(0, 0)),
          throwsA(isA<GameOverException>()),
        );
      });
    });

    group('Draw Scenario', () {
      test('full board without winner ends in GameDraw', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());

        // Classic draw sequence:
        // X O X
        // X X O
        // O X O
        final moves = [
          const Position(0, 0), // X
          const Position(0, 1), // O
          const Position(0, 2), // X
          const Position(1, 2), // O
          const Position(1, 0), // X
          const Position(2, 0), // O
          const Position(1, 1), // X
          const Position(2, 2), // O
          const Position(2, 1), // X
        ];

        for (final move in moves) {
          engine.makeMove(move);
        }

        expect(engine.isGameOver, isTrue);
        expect(engine.isDraw, isTrue);
        expect(engine.isWon, isFalse);
        expect(engine.winner, isNull);
        expect(engine.winningLine, isNull);
        expect(engine.status, equals(const GameDraw()));

        // Attempting to move after draw is blocked
        expect(
          () => engine.makeMove(const Position(0, 0)),
          throwsA(isA<GameOverException>()),
        );
      });
    });

    group('Game Reset & Starter Swapping', () {
      test('reset without arguments alternates starting player', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());
        expect(engine.startingPlayer, equals(Player.x));

        // Play one move and reset
        engine.makeMove(const Position(0, 0));
        engine.reset();

        expect(engine.startingPlayer, equals(Player.o));
        expect(engine.currentPlayer, equals(Player.o));
        expect(engine.board.occupiedCount, equals(0));
        expect(engine.moveHistory, isEmpty);
        expect(engine.isGameOver, isFalse);
      });

      test('reset with explicit nextStartingPlayer respects choice', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());
        engine.reset(nextStartingPlayer: Player.x);

        expect(engine.startingPlayer, equals(Player.x));
        expect(engine.currentPlayer, equals(Player.x));
      });

      test('reset with newConfig applies updated board dimensions', () {
        final engine = GameEngine(config: BoardConfig.classic3x3());
        engine.reset(newConfig: BoardConfig.grid6x6);

        expect(engine.config.rows, equals(6));
        expect(engine.config.cols, equals(6));
        expect(engine.config.winStreak, equals(4));
        expect(engine.board.config.totalCells, equals(36));
      });
    });
  });
}
