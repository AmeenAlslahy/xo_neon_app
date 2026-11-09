import '../../../game/domain/models/cell_position.dart';
import '../../../game/domain/models/player.dart';

/// Status of an active online match.
enum OnlineGameStatus {
  playing,
  roundWon,
  roundDraw,
  matchOver;

  static OnlineGameStatus fromString(String? val) {
    return switch (val) {
      'playing' => OnlineGameStatus.playing,
      'roundWon' => OnlineGameStatus.roundWon,
      'roundDraw' => OnlineGameStatus.roundDraw,
      'matchOver' => OnlineGameStatus.matchOver,
      _ => OnlineGameStatus.playing,
    };
  }
}

/// Represents a single move played in an online match.
class OnlineMove {
  const OnlineMove({
    required this.row,
    required this.col,
    required this.player,
    required this.timestampMs,
  });

  final int row;
  final int col;
  final Player player;
  final int timestampMs;

  Position get position => Position(row, col);

  Map<String, dynamic> toMap() => {
        'row': row,
        'col': col,
        'player': player.symbol,
        'timestampMs': timestampMs,
      };

  factory OnlineMove.fromMap(Map<dynamic, dynamic> map) {
    final sym = map['player'] as String? ?? 'X';
    return OnlineMove(
      row: (map['row'] as num?)?.toInt() ?? 0,
      col: (map['col'] as num?)?.toInt() ?? 0,
      player: sym == 'O' ? Player.o : Player.x,
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineMove &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col &&
          player == other.player;

  @override
  int get hashCode => Object.hash(row, col, player);
}

/// Domain model representing the real-time state of an active online game.
class OnlineGameState {
  const OnlineGameState({
    required this.currentRound,
    required this.currentTurn,
    required this.hostScore,
    required this.guestScore,
    required this.moves,
    this.status = OnlineGameStatus.playing,
    this.roundWinner,
    this.winningPositions,
    required this.lastUpdatedMs,
  });

  final int currentRound;
  final Player currentTurn;
  final int hostScore;
  final int guestScore;
  final List<OnlineMove> moves;
  final OnlineGameStatus status;
  final Player? roundWinner;
  final List<Position>? winningPositions;
  final int lastUpdatedMs;

  bool get isPlaying => status == OnlineGameStatus.playing;
  bool get isRoundOver =>
      status == OnlineGameStatus.roundWon || status == OnlineGameStatus.roundDraw;
  bool get isMatchOver => status == OnlineGameStatus.matchOver;

  Map<String, dynamic> toMap() => {
        'currentRound': currentRound,
        'currentTurn': currentTurn.symbol,
        'hostScore': hostScore,
        'guestScore': guestScore,
        'moves': moves.map((m) => m.toMap()).toList(),
        'status': status.name,
        'roundWinner': roundWinner?.symbol,
        'winningPositions': winningPositions
            ?.map((p) => {'row': p.row, 'col': p.col})
            .toList(),
        'lastUpdatedMs': lastUpdatedMs,
      };

  factory OnlineGameState.fromMap(Map<dynamic, dynamic> map) {
    final turnSym = map['currentTurn'] as String? ?? 'X';
    final winnerSym = map['roundWinner'] as String?;

    final rawMoves = map['moves'];
    final movesList = <OnlineMove>[];
    if (rawMoves is List) {
      for (final item in rawMoves) {
        if (item is Map) {
          movesList.add(OnlineMove.fromMap(item));
        }
      }
    } else if (rawMoves is Map) {
      // RTDB sometimes serializes arrays with sparse integer keys as Maps
      for (final val in rawMoves.values) {
        if (val is Map) {
          movesList.add(OnlineMove.fromMap(val));
        }
      }
    }

    final rawPositions = map['winningPositions'];
    List<Position>? winningPositions;
    if (rawPositions is List) {
      winningPositions = rawPositions
          .whereType<Map>()
          .map((m) => Position(
                (m['row'] as num?)?.toInt() ?? 0,
                (m['col'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    }

    return OnlineGameState(
      currentRound: (map['currentRound'] as num?)?.toInt() ?? 1,
      currentTurn: turnSym == 'O' ? Player.o : Player.x,
      hostScore: (map['hostScore'] as num?)?.toInt() ?? 0,
      guestScore: (map['guestScore'] as num?)?.toInt() ?? 0,
      moves: List.unmodifiable(movesList),
      status: OnlineGameStatus.fromString(map['status'] as String?),
      roundWinner: winnerSym == null
          ? null
          : (winnerSym == 'O' ? Player.o : Player.x),
      winningPositions: winningPositions,
      lastUpdatedMs: (map['lastUpdatedMs'] as num?)?.toInt() ?? 0,
    );
  }

  OnlineGameState copyWith({
    int? currentRound,
    Player? currentTurn,
    int? hostScore,
    int? guestScore,
    List<OnlineMove>? moves,
    OnlineGameStatus? status,
    Player? roundWinner,
    List<Position>? winningPositions,
    int? lastUpdatedMs,
  }) {
    return OnlineGameState(
      currentRound: currentRound ?? this.currentRound,
      currentTurn: currentTurn ?? this.currentTurn,
      hostScore: hostScore ?? this.hostScore,
      guestScore: guestScore ?? this.guestScore,
      moves: moves ?? this.moves,
      status: status ?? this.status,
      roundWinner: roundWinner ?? this.roundWinner,
      winningPositions: winningPositions ?? this.winningPositions,
      lastUpdatedMs: lastUpdatedMs ?? this.lastUpdatedMs,
    );
  }
}
