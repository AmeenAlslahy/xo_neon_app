import 'cell_position.dart';
import 'player.dart';

/// Represents an immutable recorded move made by a player on the board.
class Move {
  final Player player;
  final Position position;
  final int moveNumber;
  final DateTime timestamp;

  Move({
    required this.player,
    required this.position,
    required this.moveNumber,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Move &&
          runtimeType == other.runtimeType &&
          player == other.player &&
          position == other.position &&
          moveNumber == other.moveNumber &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(player, position, moveNumber, timestamp);

  @override
  String toString() =>
      'Move(#$moveNumber by ${player.symbol} at $position, time: ${timestamp.toIso8601String()})';
}
