import '../models/cell_position.dart';
import '../models/game_status.dart';
import '../models/player.dart';

/// Base class for all game-related domain exceptions.
abstract class GameException implements Exception {
  final String message;
  const GameException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when board dimensions or win conditions are invalid.
class InvalidBoardConfigException extends GameException {
  const InvalidBoardConfigException(super.message);
}

/// Base class for any invalid move attempt.
abstract class InvalidMoveException extends GameException {
  const InvalidMoveException(super.message);
}

/// Thrown when a player attempts to place a move outside the board grid.
class OutOfBoundsException extends InvalidMoveException {
  final Position position;
  final int rows;
  final int cols;

  OutOfBoundsException(this.position, this.rows, this.cols)
      : super('Position $position is out of board bounds ($rows x $cols).');
}

/// Thrown when a player attempts to move in a cell that is already occupied.
class CellAlreadyOccupiedException extends InvalidMoveException {
  final Position position;
  final Player existingPlayer;

  CellAlreadyOccupiedException(this.position, this.existingPlayer)
      : super('Cell $position is already occupied by ${existingPlayer.symbol}.');
}

/// Thrown when a move is attempted after the game has already concluded.
class GameOverException extends InvalidMoveException {
  final GameStatus status;

  GameOverException(this.status)
      : super('Cannot make a move because the game has concluded with status: $status.');
}

/// Thrown when a player attempts to play when it is not their turn.
class WrongTurnException extends InvalidMoveException {
  final Player attemptedPlayer;
  final Player expectedPlayer;

  WrongTurnException(this.attemptedPlayer, this.expectedPlayer)
      : super('It is ${expectedPlayer.symbol}\'s turn, not ${attemptedPlayer.symbol}\'s.');
}
