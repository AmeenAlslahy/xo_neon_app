import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase_options.dart';
import '../domain/logic/online_transactions.dart';
import '../../game/domain/models/cell_position.dart';
import '../../game/domain/models/player.dart';
import '../domain/models/online_game_state.dart';
import '../domain/models/room_code.dart';
import '../domain/models/room_config.dart';
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

  /// Submits a player's move atomically using runTransaction, validating turn,
  /// cell vacancy, and evaluating victory lines inside the transaction.
  Future<SubmitMoveResult> submitMove({
    required RoomModel room,
    required Position position,
    required Player player,
  }) async {
    final normalized = RoomCode.normalize(room.code);
    final gameRef = _db.ref('rooms/$normalized/game');

    try {
      final transactionResult = await gameRef.runTransaction((currentData) {
        // Empty local cache: let the SDK fetch the game and rerun the handler.
        if (currentData == null) {
          return Transaction.success(currentData);
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final outcome = evaluateSubmitMoveTransaction(
          currentData: currentData,
          position: position,
          player: player,
          room: room,
          nowMs: now,
        );

        return switch (outcome) {
          SubmitMoveTransactionAbort() => Transaction.abort(),
          SubmitMoveTransactionSuccess(:final nextMap) =>
            Transaction.success(nextMap),
        };
      });

      if (transactionResult.committed) {
        final snapVal = transactionResult.snapshot.value;
        if (snapVal is Map) {
          return SubmitMoveSuccess(OnlineGameState.fromMap(snapVal));
        }
      }

      // If aborted / not committed: pure post-transaction state derivation
      // 1. Check if the snapshot at transaction abort showed turn mismatch
      final abortedSnapVal = transactionResult.snapshot.value;
      if (abortedSnapVal is Map) {
        final abortedGame = OnlineGameState.fromMap(abortedSnapVal);
        if (abortedGame.currentTurn != player) {
          return const SubmitMoveFailure(SubmitMoveFailureReason.notYourTurn);
        }
      }

      // 2. Check latest game node in database
      final latestSnap = await gameRef.get();
      if (!latestSnap.exists || latestSnap.value is! Map) {
        return const SubmitMoveFailure(SubmitMoveFailureReason.gameMissing);
      }
      final latestGame = OnlineGameState.fromMap(latestSnap.value as Map);
      if (latestGame.status != OnlineGameStatus.playing) {
        return const SubmitMoveFailure(SubmitMoveFailureReason.notPlaying);
      }
      if (latestGame.moves.any((m) => m.row == position.row && m.col == position.col)) {
        return const SubmitMoveFailure(SubmitMoveFailureReason.cellTaken);
      }
      if (latestGame.currentTurn != player) {
        return const SubmitMoveFailure(SubmitMoveFailureReason.notYourTurn);
      }
      return const SubmitMoveFailure(SubmitMoveFailureReason.transactionAborted);
    } catch (_) {
      return const SubmitMoveFailure(SubmitMoveFailureReason.transactionAborted);
    }
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

  /// Resets the match on the same room for a rematch, resetting round, scores,
  /// and moves to initial state, optionally applying a [newConfig].
  Future<void> rematch({
    required RoomModel room,
    RoomConfig? newConfig,
  }) async {
    final normalized = RoomCode.normalize(room.code);
    final now = DateTime.now().millisecondsSinceEpoch;

    final initialGame = OnlineGameState(
      currentRound: 1,
      currentTurn: Player.x,
      hostScore: 0,
      guestScore: 0,
      moves: const [],
      status: OnlineGameStatus.playing,
      lastUpdatedMs: now,
    );

    final updates = <String, dynamic>{
      'rooms/$normalized/status': RoomStatus.inGame.name,
      'rooms/$normalized/lastActiveMs': now,
      'rooms/$normalized/game': initialGame.toMap(),
    };

    if (newConfig != null) {
      updates['rooms/$normalized/config'] = newConfig.toMap();
    }

    await _db.ref().update(updates);
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
