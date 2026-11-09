/// Configuration settings for an online XO Neon room session.
class RoomConfig {
  const RoomConfig({
    required this.boardSize,
    required this.winStreak,
    this.roundsToWin = 1,
    this.turnTimeLimitSeconds = 30,
  });

  /// The dimension of the square board (3, 6, 9, 11).
  final int boardSize;

  /// Number of contiguous marks needed to win a round (3, 4, 5, 6).
  final int winStreak;

  /// Rounds required to win the entire match (e.g. 1, 2, 3).
  final int roundsToWin;

  /// Turn timer in seconds (default 30s).
  final int turnTimeLimitSeconds;

  /// Default configuration for a quick 3x3 match.
  factory RoomConfig.standard3x3() => const RoomConfig(
        boardSize: 3,
        winStreak: 3,
        roundsToWin: 1,
      );

  /// Helper factory for a given board size with official win streaks.
  factory RoomConfig.forBoardSize(int size, {int roundsToWin = 1}) {
    final streak = switch (size) {
      3 => 3,
      6 => 4,
      9 => 5,
      11 => 6,
      _ => 3,
    };
    return RoomConfig(
      boardSize: size,
      winStreak: streak,
      roundsToWin: roundsToWin,
    );
  }

  Map<String, dynamic> toMap() => {
        'boardSize': boardSize,
        'winStreak': winStreak,
        'roundsToWin': roundsToWin,
        'turnTimeLimitSeconds': turnTimeLimitSeconds,
      };

  factory RoomConfig.fromMap(Map<dynamic, dynamic> map) {
    return RoomConfig(
      boardSize: (map['boardSize'] as num?)?.toInt() ?? 3,
      winStreak: (map['winStreak'] as num?)?.toInt() ?? 3,
      roundsToWin: (map['roundsToWin'] as num?)?.toInt() ?? 1,
      turnTimeLimitSeconds: (map['turnTimeLimitSeconds'] as num?)?.toInt() ?? 30,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomConfig &&
          runtimeType == other.runtimeType &&
          boardSize == other.boardSize &&
          winStreak == other.winStreak &&
          roundsToWin == other.roundsToWin &&
          turnTimeLimitSeconds == other.turnTimeLimitSeconds;

  @override
  int get hashCode => Object.hash(
        boardSize,
        winStreak,
        roundsToWin,
        turnTimeLimitSeconds,
      );
}
