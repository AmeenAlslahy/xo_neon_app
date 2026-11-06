import 'cell_position.dart';

/// Represents the geometric direction of a winning sequence.
enum WinDirection {
  horizontal,
  vertical,
  diagonal,      // Top-Left to Bottom-Right (\)
  antiDiagonal;  // Top-Right to Bottom-Left (/)
}

/// Represents a validated winning line on the board.
class WinningLine {
  final List<Position> positions;
  final WinDirection direction;

  WinningLine({
    required List<Position> positions,
    required this.direction,
  }) : positions = List.unmodifiable(List<Position>.from(positions));

  Position get start => positions.first;
  Position get end => positions.last;
  int get length => positions.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WinningLine &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          _listEquals(positions, other.positions);

  @override
  int get hashCode => Object.hash(direction, Object.hashAll(positions));

  @override
  String toString() =>
      'WinningLine(direction: $direction, length: $length, from: $start, to: $end)';

  static bool _listEquals(List<Position> a, List<Position> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
