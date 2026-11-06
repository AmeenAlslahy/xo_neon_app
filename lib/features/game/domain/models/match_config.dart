import 'board_config.dart';
import 'timer_config.dart';

/// Central immutable configuration for a match, including board geometry,
/// number of rounds, and chess-clock settings.
class MatchConfig {
  final BoardConfig boardConfig;
  final int totalRounds; // 1, 3 (default), 5
  final TimerConfig timerConfig;

  static const List<int> authorizedRoundCounts = [1, 3, 5];

  const MatchConfig({
    required this.boardConfig,
    this.totalRounds = 3,
    this.timerConfig = const TimerConfig.disabled(),
  }) : assert(
          totalRounds == 1 || totalRounds == 3 || totalRounds == 5,
          'Total rounds must be one of the authorized counts: 1, 3, or 5',
        );

  MatchConfig copyWith({
    BoardConfig? boardConfig,
    int? totalRounds,
    TimerConfig? timerConfig,
  }) {
    return MatchConfig(
      boardConfig: boardConfig ?? this.boardConfig,
      totalRounds: totalRounds ?? this.totalRounds,
      timerConfig: timerConfig ?? this.timerConfig,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchConfig &&
          other.boardConfig == boardConfig &&
          other.totalRounds == totalRounds &&
          other.timerConfig == timerConfig;

  @override
  int get hashCode => Object.hash(boardConfig, totalRounds, timerConfig);

  @override
  String toString() =>
      'MatchConfig(board: ${boardConfig.rows}x${boardConfig.cols}, rounds: $totalRounds, timer: $timerConfig)';
}
