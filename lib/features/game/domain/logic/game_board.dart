import 'dart:collection';
import 'dart:typed_data';

import '../models/board_config.dart';
import '../models/cell_position.dart';
import '../models/player.dart';

/// Represents the state of the game grid.
///
/// Backed internally by a high-performance [Uint8List] where:
/// - `0`: Empty cell (null)
/// - `1`: [Player.x]
/// - `2`: [Player.o]
///
/// Maintains an O(1) [occupiedCount] and [isFull] calculation.
class GameBoard {
  final BoardConfig config;
  final Uint8List _rawCells;
  int _occupiedCount;

  /// Cached unmodifiable list view mapping byte codes to [Player?] references.
  late final List<Player?> _cellsView = _BoardCellsView(_rawCells);

  GameBoard._raw(this.config, this._rawCells, this._occupiedCount);

  /// Creates a blank board with all cells set to empty (null).
  factory GameBoard.empty(BoardConfig config) {
    return GameBoard._raw(
      config,
      Uint8List(config.totalCells),
      0,
    );
  }

  /// Creates a board from an existing list of cells with defensive copy.
  factory GameBoard.fromCells(BoardConfig config, List<Player?> cells) {
    if (cells.length != config.totalCells) {
      throw ArgumentError(
        'Cells length (${cells.length}) must match config totalCells (${config.totalCells}).',
      );
    }
    final raw = Uint8List(config.totalCells);
    var count = 0;
    for (var i = 0; i < cells.length; i++) {
      final p = cells[i];
      if (p == Player.x) {
        raw[i] = 1;
        count++;
      } else if (p == Player.o) {
        raw[i] = 2;
        count++;
      }
    }
    return GameBoard._raw(config, raw, count);
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
    final v = _rawCells[_toIndex(p)];
    if (v == 1) return Player.x;
    if (v == 2) return Player.o;
    return null;
  }

  /// Direct flat-index access (faster for search loops).
  Player? cellAtIndex(int index) {
    if (index < 0 || index >= _rawCells.length) return null;
    final v = _rawCells[index];
    if (v == 1) return Player.x;
    if (v == 2) return Player.o;
    return null;
  }

  /// Direct raw byte code access (0=empty, 1=X, 2=O).
  int rawCellAtIndex(int index) => _rawCells[index];

  /// Raw backing byte buffer (read-only for search/geometry fast paths).
  Uint8List get rawCells => _rawCells;

  /// Returns true if the cell at [p] is within bounds and unoccupied.
  bool isEmpty(Position p) {
    return isWithinBounds(p) && _rawCells[_toIndex(p)] == 0;
  }

  /// Returns true if the cell at flat [index] is unoccupied.
  bool isIndexEmpty(int index) {
    return index >= 0 && index < _rawCells.length && _rawCells[index] == 0;
  }

  /// Number of cells currently marked by any player. O(1).
  int get occupiedCount => _occupiedCount;

  /// True if all cells on the board have been filled. O(1).
  bool get isFull => _occupiedCount == config.totalCells;

  /// Returns a new immutable [GameBoard] instance with [player] placed at [position].
  GameBoard copyWithMove(Position position, Player player) {
    final idx = _toIndex(position);
    final nextRaw = Uint8List.fromList(_rawCells);
    final prev = nextRaw[idx];
    nextRaw[idx] = player == Player.x ? 1 : 2;
    final nextCount = prev == 0 ? _occupiedCount + 1 : _occupiedCount;
    return GameBoard._raw(config, nextRaw, nextCount);
  }

  /// Mutates the board in-place for search routines to avoid allocations.
  /// Must be paired with [undo] at the end of the branch.
  GameBoard copyWithMoveInPlace(Position position, Player player) {
    final idx = _toIndex(position);
    if (_rawCells[idx] == 0) {
      _occupiedCount++;
    }
    _rawCells[idx] = player == Player.x ? 1 : 2;
    return this;
  }

  /// Mutates the board in-place by flat index for maximum speed in search loops.
  GameBoard copyWithMoveIndexInPlace(int index, Player player) {
    if (_rawCells[index] == 0) {
      _occupiedCount++;
    }
    _rawCells[index] = player == Player.x ? 1 : 2;
    return this;
  }

  /// Reverses an in-place move made by [copyWithMoveInPlace].
  void undo(Position position) {
    final idx = _toIndex(position);
    if (_rawCells[idx] != 0) {
      _occupiedCount--;
      _rawCells[idx] = 0;
    }
  }

  /// Reverses an in-place move made by [copyWithMoveIndexInPlace].
  void undoIndex(int index) {
    if (_rawCells[index] != 0) {
      _occupiedCount--;
      _rawCells[index] = 0;
    }
  }

  /// Unmodifiable view of the raw flat cells list.
  List<Player?> get cells => _cellsView;

  /// Returns an unmodifiable 2D representation [rows][cols] of the board.
  List<List<Player?>> to2DList() {
    return List<List<Player?>>.unmodifiable(
      List.generate(
        config.rows,
        (r) => List<Player?>.unmodifiable(
          List.generate(
            config.cols,
            (c) => cellAt(Position(r, c)),
            growable: false,
          ),
        ),
        growable: false,
      ),
    );
  }
}

/// Lightweight unmodifiable [ListBase] view backed directly by [Uint8List].
class _BoardCellsView extends ListBase<Player?> {
  final Uint8List _raw;
  _BoardCellsView(this._raw);

  @override
  int get length => _raw.length;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Cannot modify unmodifiable board cells');

  @override
  Player? operator [](int index) {
    final v = _raw[index];
    if (v == 1) return Player.x;
    if (v == 2) return Player.o;
    return null;
  }

  @override
  void operator []=(int index, Player? value) =>
      throw UnsupportedError('Cannot modify unmodifiable board cells');
}
