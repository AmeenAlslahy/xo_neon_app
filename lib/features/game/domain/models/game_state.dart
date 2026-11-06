import 'board_config.dart';
import 'game_status.dart';
import 'move.dart';
import 'player.dart';
import 'winning_line.dart';
import '../logic/game_board.dart';

/// Immutable snapshot representing the entire state of a game at any point in time.
class GameState {
  final BoardConfig config;
  final GameBoard board;
  final Player startingPlayer;
  final Player currentPlayer;
  final GameStatus status;
  final List<Move> moveHistory;

  GameState({
    required this.config,
    required this.board,
    required this.startingPlayer,
    required this.currentPlayer,
    required this.status,
    required List<Move> moveHistory,
  }) : moveHistory = List.unmodifiable(moveHistory);

  /// Factory to initialize a fresh game state.
  factory GameState.initial({
    required BoardConfig config,
    Player startingPlayer = Player.x,
  }) {
    return GameState(
      config: config,
      board: GameBoard.empty(config),
      startingPlayer: startingPlayer,
      currentPlayer: startingPlayer,
      status: GameInProgress(startingPlayer),
      moveHistory: const [],
    );
  }

  bool get isGameOver => status.isTerminal;
  bool get isDraw => status is GameDraw;
  bool get isWon => status is GameWon;

  Player? get winner => status is GameWon ? (status as GameWon).winner : null;
  WinningLine? get winningLine =>
      status is GameWon ? (status as GameWon).winningLine : null;

  int get moveCount => moveHistory.length;

  GameState copyWith({
    BoardConfig? config,
    GameBoard? board,
    Player? startingPlayer,
    Player? currentPlayer,
    GameStatus? status,
    List<Move>? moveHistory,
  }) {
    return GameState(
      config: config ?? this.config,
      board: board ?? this.board,
      startingPlayer: startingPlayer ?? this.startingPlayer,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      status: status ?? this.status,
      moveHistory: moveHistory ?? this.moveHistory,
    );
  }
}

