import 'game_state.dart';
import 'match_config.dart';
import 'player.dart';

/// Exhaustive phases of a match lifecycle.
enum MatchPhase {
  inProgress,
  roundEnded,
  paused,
  matchEnded,
}

/// Reason why a specific round concluded.
enum RoundEndReason {
  win,
  draw,
  timeout,
}

/// Immutable snapshot representing the authoritative state of a match.
class MatchState {
  final MatchConfig config;
  final int currentRound;
  final int scoreX;
  final int scoreO;
  final Player roundStartingPlayer;
  final GameState roundState;
  final MatchPhase phase;
  final RoundEndReason? roundEndReason;
  final Player? roundWinner;
  final Duration remainingTimeX;
  final Duration remainingTimeO;
  final Player? matchWinner;

  const MatchState({
    required this.config,
    required this.currentRound,
    required this.scoreX,
    required this.scoreO,
    required this.roundStartingPlayer,
    required this.roundState,
    required this.phase,
    this.roundEndReason,
    this.roundWinner,
    required this.remainingTimeX,
    required this.remainingTimeO,
    this.matchWinner,
  });

  /// Factory creating the fresh initial state for a new match.
  factory MatchState.initial({
    required MatchConfig config,
    Player startingPlayer = Player.x,
  }) {
    final initialDuration = config.timerConfig.durationPerPlayer;
    return MatchState(
      config: config,
      currentRound: 1,
      scoreX: 0,
      scoreO: 0,
      roundStartingPlayer: startingPlayer,
      roundState: GameState.initial(
        config: config.boardConfig,
        startingPlayer: startingPlayer,
      ),
      phase: MatchPhase.inProgress,
      roundEndReason: null,
      roundWinner: null,
      remainingTimeX: initialDuration,
      remainingTimeO: initialDuration,
      matchWinner: null,
    );
  }

  bool get isFinalRound => currentRound >= config.totalRounds;
  bool get isMatchOver => phase == MatchPhase.matchEnded;
  bool get isRoundOver => phase == MatchPhase.roundEnded || phase == MatchPhase.matchEnded;
  bool get isPaused => phase == MatchPhase.paused;
  bool get isTimerEnabled => config.timerConfig.enabled;
  bool get isMatchDraw => isMatchOver && scoreX == scoreO;

  /// The player whose turn it currently is on the board.
  Player get currentTurnPlayer => roundState.currentPlayer;

  /// Remaining clock time for a specific player.
  Duration remainingTimeFor(Player player) =>
      player == Player.x ? remainingTimeX : remainingTimeO;

  MatchState copyWith({
    MatchConfig? config,
    int? currentRound,
    int? scoreX,
    int? scoreO,
    Player? roundStartingPlayer,
    GameState? roundState,
    MatchPhase? phase,
    RoundEndReason? roundEndReason,
    bool clearRoundEndReason = false,
    Player? roundWinner,
    bool clearRoundWinner = false,
    bool clearRoundResult = false,
    Duration? remainingTimeX,
    Duration? remainingTimeO,
    Player? matchWinner,
    bool clearMatchWinner = false,
  }) {
    return MatchState(
      config: config ?? this.config,
      currentRound: currentRound ?? this.currentRound,
      scoreX: scoreX ?? this.scoreX,
      scoreO: scoreO ?? this.scoreO,
      roundStartingPlayer: roundStartingPlayer ?? this.roundStartingPlayer,
      roundState: roundState ?? this.roundState,
      phase: phase ?? this.phase,
      roundEndReason: (clearRoundResult || clearRoundEndReason)
          ? null
          : (roundEndReason ?? this.roundEndReason),
      roundWinner: (clearRoundResult || clearRoundWinner)
          ? null
          : (roundWinner ?? this.roundWinner),
      remainingTimeX: remainingTimeX ?? this.remainingTimeX,
      remainingTimeO: remainingTimeO ?? this.remainingTimeO,
      matchWinner: clearMatchWinner ? null : (matchWinner ?? this.matchWinner),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchState &&
          other.config == config &&
          other.currentRound == currentRound &&
          other.scoreX == scoreX &&
          other.scoreO == scoreO &&
          other.roundStartingPlayer == roundStartingPlayer &&
          other.roundState == roundState &&
          other.phase == phase &&
          other.roundEndReason == roundEndReason &&
          other.roundWinner == roundWinner &&
          other.remainingTimeX == remainingTimeX &&
          other.remainingTimeO == remainingTimeO &&
          other.matchWinner == matchWinner;

  @override
  int get hashCode => Object.hash(
        config,
        currentRound,
        scoreX,
        scoreO,
        roundStartingPlayer,
        roundState,
        phase,
        roundEndReason,
        roundWinner,
        remainingTimeX,
        remainingTimeO,
        matchWinner,
      );
}
