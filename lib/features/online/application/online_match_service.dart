import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase_options.dart';
import '../../game/domain/logic/game_board.dart';
import '../../game/domain/logic/win_evaluator.dart';
import '../../game/domain/models/board_config.dart';
import '../../game/domain/models/cell_position.dart';
import '../../game/domain/models/player.dart';
import '../domain/models/online_game_state.dart';
import '../domain/models/room_code.dart';
import '../domain/models/room_model.dart';

/// Service coordinating real-time move submissions, board evaluation, and
/// round progression against Firebase Realtime Database.
class OnlineMatchService {
  OnlineMatchService({this.database});

  final FirebaseDatabase? database;

  FirebaseDatabase get _db {
    if (database != null) return database!;
    final databaseUrl = DefaultFirebaseOptions.currentPlatform.databaseURL;
    if (databaseUrl != null && databaseUrl.isNotEmpty) {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseUrl,
      );
    }
    return FirebaseDatabase.instance;
  }

  /// Initializes the initial game state node under `/rooms/<roomCode>/game`.
  Future<OnlineGameState> initializeGame(RoomModel room) async {
    final normalized = RoomCode.normalize(room.code);
    final now = DateTime.now().millisecondsSinceEpoch;

    final initialState = OnlineGameState(
      currentRound: 1,
      currentTurn: Player.x,
      hostScore: 0,
      guestScore: 0,
      moves: const [],
      status: OnlineGameStatus.playing,
      lastUpdatedMs: now,
    );

    final gameRef = _db.ref('rooms/$normalized/game');
    await gameRef.set(initialState.toMap());
    return initialState;
  }

  /// Streams real-time updates for an active match.
  Stream<OnlineGameState?> streamGame(String roomCode) {
    final normalized = RoomCode.normalize(roomCode);
    final gameRef = _db.ref('rooms/$normalized/game');

    return gameRef.onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return null;
      return OnlineGameState.fromMap(val);
    });
  }

  /// Submits a player's move, validates turn, checks for victory lines,
  /// and updates the shared match state in RTDB.
  Future<bool> submitMove({
    required RoomModel room,
    required Position position,
    required Player player,
  }) async {
    final normalized = RoomCode.normalize(room.code);
    final gameRef = _db.ref('rooms/$normalized/game');
    final snapshot = await gameRef.get();

    if (!snapshot.exists || snapshot.value is! Map) {
      return false;
    }

    final current = OnlineGameState.fromMap(snapshot.value as Map);

    // Guard: Game must be actively playing
    if (current.status != OnlineGameStatus.playing) {
      return false;
    }

    // Guard: Must be the submitting player's turn
    if (current.currentTurn != player) {
      return false;
    }

    // Guard: Cell must not already be occupied
    final alreadyTaken = current.moves.any(
      (m) => m.row == position.row && m.col == position.col,
    );
    if (alreadyTaken) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newMove = OnlineMove(
      row: position.row,
      col: position.col,
      player: player,
      timestampMs: now,
    );

    final updatedMoves = [...current.moves, newMove];

    final boardConfig = BoardConfig(
      rows: room.config.boardSize,
      cols: room.config.boardSize,
      winStreak: room.config.winStreak,
    );

    // Reconstruct domain GameBoard to evaluate winning line
    var board = GameBoard.empty(boardConfig);
    for (final m in updatedMoves) {
      board = board.copyWithMove(m.position, m.player);
    }

    // Evaluate for victory using the pure domain WinEvaluator
    const evaluator = WinEvaluator();
    final winLines = evaluator.findAllWinningLinesFromMove(
      board: board,
      lastMove: position,
      player: player,
    );

    OnlineGameStatus nextStatus;
    Player? roundWinner;
    List<Position>? winningPositions;
    int nextHostScore = current.hostScore;
    int nextGuestScore = current.guestScore;

    if (winLines.isNotEmpty) {
      roundWinner = player;
      winningPositions = winLines.first.positions;

      if (player == Player.x) {
        nextHostScore++;
      } else {
        nextGuestScore++;
      }

      final isMatchOver = nextHostScore >= room.config.roundsToWin ||
          nextGuestScore >= room.config.roundsToWin;

      nextStatus =
          isMatchOver ? OnlineGameStatus.matchOver : OnlineGameStatus.roundWon;
    } else if (board.isFull) {
      nextStatus = OnlineGameStatus.roundDraw;
    } else {
      nextStatus = OnlineGameStatus.playing;
    }

    final nextTurn = player.other;

    final nextState = current.copyWith(
      moves: updatedMoves,
      currentTurn: nextTurn,
      status: nextStatus,
      roundWinner: roundWinner,
      winningPositions: winningPositions,
      hostScore: nextHostScore,
      guestScore: nextGuestScore,
      lastUpdatedMs: now,
    );

    await gameRef.set(nextState.toMap());
    return true;
  }

  /// Advances match to the next round, alternating the starter.
  Future<void> advanceNextRound({
    required RoomModel room,
    required OnlineGameState currentState,
  }) async {
    final normalized = RoomCode.normalize(room.code);
    final gameRef = _db.ref('rooms/$normalized/game');
    final nextRoundNumber = currentState.currentRound + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Starter alternates every round (Round 1: X, Round 2: O, Round 3: X...)
    final nextStarter = nextRoundNumber % 2 == 1 ? Player.x : Player.o;

    final nextRoundState = OnlineGameState(
      currentRound: nextRoundNumber,
      currentTurn: nextStarter,
      hostScore: currentState.hostScore,
      guestScore: currentState.guestScore,
      moves: const [],
      status: OnlineGameStatus.playing,
      lastUpdatedMs: now,
    );

    await gameRef.set(nextRoundState.toMap());
  }
}

/// Provider exposing the singleton [OnlineMatchService].
final onlineMatchServiceProvider = Provider<OnlineMatchService>((ref) {
  return OnlineMatchService();
});

/// Family stream provider watching an active online match's state.
final onlineGameStreamProvider =
    StreamProvider.autoDispose.family<OnlineGameState?, String>((ref, code) {
  final service = ref.watch(onlineMatchServiceProvider);
  return service.streamGame(code);
});
