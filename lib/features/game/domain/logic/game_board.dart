import '../models/board_config.dart';
import '../models/cell_position.dart';
import '../models/player.dart';

/// Represents the immutable state of the game grid.
class GameBoard {
  final BoardConfig config;
  final List<Player?> _cells;

  GameBoard._(this.config, List<Player?> cells)
      : _cells = List<Player?>.unmodifiable(List<Player?>.from(cells, growable: false));

  /// Creates a blank board with all cells set to empty (null).
  factory GameBoard.empty(BoardConfig config) {
    return GameBoard._(
      config,
      List<Player?>.filled(config.totalCells, null, growable: false),
    );
  }

  /// Creates a board from an existing list of cells with defensive copy.
  factory GameBoard.fromCells(BoardConfig config, List<Player?> cells) {
    if (cells.length != config.totalCells) {
      throw ArgumentError(
        'Cells length (${cells.length}) must match config totalCells (${config.totalCells}).',
      );
    }
    return GameBoard._(config, cells);
  }

  /// Converts a [Position] to a flat 1D index.
  int _toIndex(Position p) => p.row * config.cols + p.col;

  /// Checks if [p] is within board boundaries.
  bool isWithinBounds(Position p) {
    return p.row >= 0 &&
        p.row < config.rows &&
        p.col >= 0 &&
        p.col < config.cols;
  }

  /// Returns the player in the cell at [p], or null if empty.
  Player? cellAt(Position p) {
    if (!isWithinBounds(p)) return null;
    return _cells[_toIndex(p)];
  }

  /// Returns true if the cell at [p] is within bounds and unoccupied.
  bool isEmpty(Position p) {
    return isWithinBounds(p) && _cells[_toIndex(p)] == null;
  }

  /// Number of cells currently marked by any player.
  int get occupiedCount => _cells.where((c) => c != null).length;

  /// True if all cells on the board have been filled.
  bool get isFull => occupiedCount == config.totalCells;

  /// Returns a new [GameBoard] instance with [player] placed at [position].
  GameBoard copyWithMove(Position position, Player player) {
    final nextCells = List<Player?>.from(_cells, growable: false);
    nextCells[_toIndex(position)] = player;
    return GameBoard._(config, nextCells);
  }

  /// Unmodifiable view of the raw flat cells list.
  List<Player?> get cells => _cells;

  /// Returns an unmodifiable 2D representation [rows][cols] of the board.
  List<List<Player?>> to2DList() {
    return List<List<Player?>>.unmodifiable(
      List.generate(
        config.rows,
        (r) => List<Player?>.unmodifiable(
          List.generate(
            config.cols,
            (c) => _cells[r * config.cols + c],
            growable: false,
          ),
        ),
        growable: false,
      ),
    );
  }
}
