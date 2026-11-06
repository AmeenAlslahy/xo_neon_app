import '../exceptions/game_exceptions.dart';
import '../models/board_config.dart';
import '../models/cell_position.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/move.dart';
import '../models/player.dart';
import '../models/winning_line.dart';
import 'game_board.dart';
import 'win_evaluator.dart';

/// The authoritative game engine coordinating rules, turns, moves, and outcomes.
///
/// Can be used as a stateful coordinator ([GameEngine] instance) or as a pure
/// functional transition pipeline via [GameEngine.applyMove].
class GameEngine {
  final WinEvaluator evaluator;
  final DateTime Function() clock;
  GameState _state;

  GameEngine({
    required BoardConfig config,
    Player startingPlayer = Player.x,
    this.evaluator = const WinEvaluator(),
    this.clock = DateTime.now,
  }) : _state = GameState.initial(
          config: config,
          startingPlayer: startingPlayer,
        );

  /// Current immutable snapshot of the game.
  GameState get state => _state;

  BoardConfig get config => _state.config;
  GameBoard get board => _state.board;
  Player get currentPlayer => _state.currentPlayer;
  Player get startingPlayer => _state.startingPlayer;
  GameStatus get status => _state.status;
  List<Move> get moveHistory => _state.moveHistory;

  bool get isGameOver => _state.isGameOver;
  bool get isDraw => _state.isDraw;
  bool get isWon => _state.isWon;
  Player? get winner => _state.winner;
  WinningLine? get winningLine => _state.winningLine;
  List<WinningLine>? get allWinningLines =>
      _state.status is GameWon ? (_state.status as GameWon).allWinningLines : null;

  /// Pure functional state transition.
  /// Given an immutable [currentState] and a target [position], validates and returns a new [GameState].
  ///
  /// Throws:
  /// - [GameOverException] if [currentState.isGameOver].
  /// - [WrongTurnException] if [player] is passed and does not match [currentState.currentPlayer].
  /// - [OutOfBoundsException] if [position] is outside [currentState.config].
  /// - [CellAlreadyOccupiedException] if cell is already marked.
  static GameState applyMove({
    required GameState currentState,
    required Position position,
    Player? player,
    required DateTime timestamp,
    WinEvaluator evaluator = const WinEvaluator(),
  }) {
    // 1. Guard against moves after game conclusion
    if (currentState.isGameOver) {
      throw GameOverException(currentState.status);
    }

    // 2. Validate player turn if explicitly specified
    if (player != null && player != currentState.currentPlayer) {
      throw WrongTurnException(player, currentState.currentPlayer);
    }

    // 3. Validate coordinates within board bounds
    if (!currentState.board.isWithinBounds(position)) {
      throw OutOfBoundsException(
        position,
        currentState.config.rows,
        currentState.config.cols,
      );
    }

    // 4. Validate that cell is vacant
    if (!currentState.board.isEmpty(position)) {
      throw CellAlreadyOccupiedException(
        position,
        currentState.board.cellAt(position)!,
      );
    }

    final activePlayer = currentState.currentPlayer;
    final updatedBoard = currentState.board.copyWithMove(position, activePlayer);
    final recordedMove = Move(
      player: activePlayer,
      position: position,
      moveNumber: currentState.moveHistory.length + 1,
      timestamp: timestamp,
    );
    final updatedHistory = List<Move>.unmodifiable([
      ...currentState.moveHistory,
      recordedMove,
    ]);

    // 5. Evaluate win condition (all lines passing through position)
    final detectedLines = evaluator.findAllWinningLinesFromMove(
      board: updatedBoard,
      lastMove: position,
      player: activePlayer,
    );

    if (detectedLines.isNotEmpty) {
      return currentState.copyWith(
        board: updatedBoard,
        status: GameWon(
          winner: activePlayer,
          winningLine: detectedLines.first,
          allWinningLines: detectedLines,
        ),
        moveHistory: updatedHistory,
      );
    }

    // 6. Check for draw (full board with no winner)
    if (updatedBoard.isFull) {
      return currentState.copyWith(
        board: updatedBoard,
        status: const GameDraw(),
        moveHistory: updatedHistory,
      );
    }

    // 7. Advance turn to next player
    final nextPlayer = activePlayer.other;
    return currentState.copyWith(
      board: updatedBoard,
      currentPlayer: nextPlayer,
      status: GameInProgress(nextPlayer),
      moveHistory: updatedHistory,
    );
  }

  /// Stateful move execution delegating to [applyMove].
  /// Uses [timestamp] if provided, otherwise samples [clock].
  GameState makeMove(Position position, {Player? player, DateTime? timestamp}) {
    _state = applyMove(
      currentState: _state,
      position: position,
      player: player,
      timestamp: timestamp ?? clock(),
      evaluator: evaluator,
    );
    return _state;
  }

  /// Resets the game to an empty board.
  /// If [nextStartingPlayer] is omitted, alternates starting player from previous game.
  GameState reset({Player? nextStartingPlayer, BoardConfig? newConfig}) {
    final nextStarter = nextStartingPlayer ?? _state.startingPlayer.other;
    final activeConfig = newConfig ?? _state.config;

    _state = GameState.initial(
      config: activeConfig,
      startingPlayer: nextStarter,
    );
    return _state;
  }
}
