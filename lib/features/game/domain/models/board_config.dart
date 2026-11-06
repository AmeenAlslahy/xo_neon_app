import 'dart:math' as math;
import '../exceptions/game_exceptions.dart';

/// Configuration for board dimensions and win conditions.
///
/// Centralized Source of Truth for authorized game grid sizes and win rules.
class BoardConfig {
  final int rows;
  final int cols;
  final int winStreak;

  const BoardConfig({
    required this.rows,
    required this.cols,
    required this.winStreak,
  });

  /// The four officially authorized grid presets:
  /// - 3x3: 3 consecutive marks to win
  /// - 6x6: 4 consecutive marks to win
  /// - 9x9: 5 consecutive marks to win
  /// - 11x11: 6 consecutive marks to win
  static const BoardConfig grid3x3 = BoardConfig(rows: 3, cols: 3, winStreak: 3);
  static const BoardConfig grid6x6 = BoardConfig(rows: 6, cols: 6, winStreak: 4);
  static const BoardConfig grid9x9 = BoardConfig(rows: 9, cols: 9, winStreak: 5);
  static const BoardConfig grid11x11 = BoardConfig(rows: 11, cols: 11, winStreak: 6);

  /// Centralized list of all authorized configurations for UI and matchmaking.
  static const List<BoardConfig> authorizedPresets = [
    grid3x3,
    grid6x6,
    grid9x9,
    grid11x11,
  ];

  /// Factory constructors for authorized presets
  factory BoardConfig.classic3x3() => grid3x3;
  factory BoardConfig.tactical6x6() => grid6x6;
  factory BoardConfig.pro9x9() => grid9x9;
  factory BoardConfig.giant11x11() => grid11x11;

  /// Centralized lookup for authorized win streak by grid dimension.
  static int winStreakForSize(int size) {
    switch (size) {
      case 3:
        return 3;
      case 6:
        return 4;
      case 9:
        return 5;
      case 11:
        return 6;
      default:
        throw InvalidBoardConfigException(
          'Unsupported authorized grid size: $size. Allowed sizes are 3, 6, 9, 11.',
        );
    }
  }

  /// Creates a validated board config for authorized size.
  factory BoardConfig.fromSize(int size) {
    return BoardConfig(
      rows: size,
      cols: size,
      winStreak: winStreakForSize(size),
    );
  }

  /// General validation constructor allowing custom rectangular or arbitrary
  /// boards within the engine without compromising central presets.
  factory BoardConfig.validated({
    required int rows,
    required int cols,
    required int winStreak,
  }) {
    if (rows < 1 || cols < 1) {
      throw InvalidBoardConfigException(
        'Board dimensions must be at least 1x1. Received: ${rows}x$cols.',
      );
    }
    if (winStreak < 1) {
      throw InvalidBoardConfigException(
        'Win streak must be at least 1. Received: $winStreak.',
      );
    }
    final maxDimension = math.max(rows, cols);
    if (winStreak > maxDimension) {
      throw InvalidBoardConfigException(
        'Win streak ($winStreak) cannot exceed maximum board dimension ($maxDimension).',
      );
    }
    return BoardConfig(rows: rows, cols: cols, winStreak: winStreak);
  }

  int get totalCells => rows * cols;
  bool get isSquare => rows == cols;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardConfig &&
          runtimeType == other.runtimeType &&
          rows == other.rows &&
          cols == other.cols &&
          winStreak == other.winStreak;

  @override
  int get hashCode => Object.hash(rows, cols, winStreak);

  @override
  String toString() => 'BoardConfig(${rows}x$cols, winStreak: $winStreak)';
}
