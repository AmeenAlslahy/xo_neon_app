import '../ai/system_move_selector.dart';
import 'board_config.dart';
import 'player.dart';
import 'timer_config.dart';

/// Central immutable configuration for a match, including board geometry,
/// number of rounds, chess-clock settings, and the opponent mode (local two
/// players or the system player with its level and the human's mark).
class MatchConfig {
  final BoardConfig boardConfig;
  final int totalRounds; // 1, 3 (default), 5
  final TimerConfig timerConfig;

  /// True when the second side is the system player (P1 move-selection core).
  final bool vsSystem;

  /// The human player's fixed mark for the whole match; the system plays the
  /// other mark. Marks and scores never swap during the match.
  final Player humanPlayer;

  /// Difficulty of the system move-selection core (only meaningful when
  /// [vsSystem] is true).
  final SystemDifficulty systemDifficulty;

  /// The mark the system plays (the complement of [humanPlayer]).
  Player get systemPlayer => humanPlayer.other;

  static const List<int> authorizedRoundCounts = [1, 3, 5];

  const MatchConfig({
    required this.boardConfig,
    this.totalRounds = 3,
    this.timerConfig = const TimerConfig.disabled(),
    this.vsSystem = false,
    this.humanPlayer = Player.x,
    this.systemDifficulty = SystemDifficulty.medium,
  }) : assert(
          totalRounds == 1 || totalRounds == 3 || totalRounds == 5,
          'Total rounds must be one of the authorized counts: 1, 3, or 5',
        );

  MatchConfig copyWith({
    BoardConfig? boardConfig,
    int? totalRounds,
    TimerConfig? timerConfig,
    bool? vsSystem,
    Player? humanPlayer,
    SystemDifficulty? systemDifficulty,
  }) {
    return MatchConfig(
      boardConfig: boardConfig ?? this.boardConfig,
      totalRounds: totalRounds ?? this.totalRounds,
      timerConfig: timerConfig ?? this.timerConfig,
      vsSystem: vsSystem ?? this.vsSystem,
      humanPlayer: humanPlayer ?? this.humanPlayer,
      systemDifficulty: systemDifficulty ?? this.systemDifficulty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchConfig &&
          other.boardConfig == boardConfig &&
          other.totalRounds == totalRounds &&
          other.timerConfig == timerConfig &&
          other.vsSystem == vsSystem &&
          other.humanPlayer == humanPlayer &&
          other.systemDifficulty == systemDifficulty;

  @override
  int get hashCode => Object.hash(
        boardConfig,
        totalRounds,
        timerConfig,
        vsSystem,
        humanPlayer,
        systemDifficulty,
      );

  @override
  String toString() =>
      'MatchConfig(board: ${boardConfig.rows}x${boardConfig.cols}, rounds: $totalRounds, timer: $timerConfig, vsSystem: $vsSystem, human: ${humanPlayer.symbol}, level: ${systemDifficulty.name})';
}
