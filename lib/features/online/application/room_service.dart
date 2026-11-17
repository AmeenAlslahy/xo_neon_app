import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase_options.dart';
import '../../game/domain/models/player.dart';
import '../domain/logic/online_transactions.dart';
import '../domain/models/online_game_state.dart';
import '../domain/models/room_code.dart';
import '../domain/models/room_config.dart';
import '../domain/models/room_model.dart';

/// Sealed result of an attempt to join an existing online room.
sealed class JoinRoomResult {
  const JoinRoomResult();

  bool get isSuccess => this is JoinRoomSuccess;
  String? get guestUid => switch (this) {
    JoinRoomSuccess(:final room) => room.guestUid,
    _ => null,
  };
}

class JoinRoomSuccess extends JoinRoomResult {
  const JoinRoomSuccess(this.room);
  final RoomModel room;
}

class JoinRoomNotFound extends JoinRoomResult {
  const JoinRoomNotFound();
}

class JoinRoomAlreadyFull extends JoinRoomResult {
  const JoinRoomAlreadyFull();
}

/// Why joining a room failed, expressed in terms the UI can translate.
enum JoinRoomFailureReason {
  invalidCode,
  roomUnavailable,
  connection,
  tooManyRequests,
  serviceUnavailable,
}

class JoinRoomError extends JoinRoomResult {
  const JoinRoomError(this.reason);
  final JoinRoomFailureReason reason;
}

/// Sealed result of an attempt to leave a room or match.
sealed class LeaveRoomResult {
  const LeaveRoomResult();
}

class LeaveRoomSuccess extends LeaveRoomResult {
  const LeaveRoomSuccess();
}

class LeaveRoomFailure extends LeaveRoomResult {
  const LeaveRoomFailure(this.error);
  final Object error;
}

/// Sealed result of an attempt to change a room's match settings.
sealed class UpdateRoomConfigResult {
  const UpdateRoomConfigResult();
}

class UpdateRoomConfigSuccess extends UpdateRoomConfigResult {
  const UpdateRoomConfigSuccess(this.config);
  final RoomConfig config;
}

class UpdateRoomConfigNotAllowed extends UpdateRoomConfigResult {
  const UpdateRoomConfigNotAllowed(this.reason);
  final String reason;
}

class UpdateRoomConfigFailure extends UpdateRoomConfigResult {
  const UpdateRoomConfigFailure(this.error);
  final Object error;
}

/// Service managing room lifecycle operations in Firebase Realtime Database.
class RoomService {
  RoomService({this.database});

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

  /// Read-only diagnostics: confirms which project/app the database client is
  /// bound to and whether the server accepts an authenticated read.
  Future<void> _logDatabaseDiagnostics(String code) async {
    try {
      final apps = Firebase.apps
          .map((app) => '${app.name}:${app.options.projectId}')
          .join(',');
      debugPrint(
        'XO_DB apps=[$apps] dbApp=${_db.app.name} dbUrl=${_db.databaseURL}',
      );
    } catch (error) {
      debugPrint('XO_DB identity error=$error');
    }

    for (final probePath in ['rooms/$code']) {
      await _probeRead(probePath);
    }
  }

  Future<void> _probeRead(String probePath) async {
    try {
      final snapshot = await _db
          .ref(probePath)
          .get()
          .timeout(const Duration(seconds: 8));
      debugPrint(
        'XO_DB probe=$probePath exists=${snapshot.exists} '
        'hasValue=${snapshot.value != null}',
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'XO_DB probe=$probePath error code=${error.code} '
        'message=${error.message}',
      );
    } catch (error) {
      debugPrint('XO_DB probe=$probePath unexpected=$error');
    }
  }

  /// Generates a new room with [config] and writes it to `/rooms/<code >`.
  Future<RoomModel> createRoom({
    required RoomConfig config,
    required String hostUid,
    String hostName = 'Player 1',
  }) async {
    final code = RoomCode.generate().value;
    final now = DateTime.now().millisecondsSinceEpoch;

    final room = RoomModel(
      code: code,
      hostUid: hostUid,
      hostName: hostName,
      config: config,
      status: RoomStatus.waitingForGuest,
      createdAtMs: now,
      lastActiveMs: now,
    );

    final roomRef = _db.ref('rooms/$code');
    await roomRef.set(room.toMap());

    // When host disconnects while in lobby, mark room abandoned with hostDisconnected termination
    await registerHostLobbyDisconnect(roomCode: code, hostUid: hostUid);

    return room;
  }

  /// Fetches a room snapshot once.
  Future<RoomModel?> getRoom(String roomCode) async {
    final normalized = RoomCode.normalize(roomCode);
    final roomRef = _db.ref('rooms/$normalized');
    final snapshot = await roomRef.get();
    if (!snapshot.exists || snapshot.value is! Map) return null;
    return RoomModel.fromMap(normalized, snapshot.value as Map);
  }

  /// Attempts to join a room atomically using runTransaction.
  Future<JoinRoomResult> joinRoom({
    required String rawCode,
    required String guestUid,
    String guestName = 'Player 2',
  }) async {
    final normalized = RoomCode.normalize(rawCode);
    if (!RoomCode.isValid(normalized)) {
      return const JoinRoomError(JoinRoomFailureReason.invalidCode);
    }

    if (kDebugMode) {
      await _logDatabaseDiagnostics(normalized);
    }

    final roomRef = _db.ref('rooms/$normalized');

    try {
      final transactionResult = await roomRef.runTransaction((currentData) {
        // The Android client invokes the handler first with its local cache,
        // which is empty right after app start. Aborting here cancels the
        // whole transaction before RTDB ever asks the server. Returning an
        // unchanged value lets the SDK fetch the room and re-run the handler
        // with the real snapshot.
        if (currentData == null) {
          if (kDebugMode) {
            debugPrint('XO_TX local cache empty; waiting for server snapshot');
          }
          return Transaction.success(currentData);
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final outcome = evaluateJoinRoomTransaction(
          currentData: currentData,
          normalizedCode: normalized,
          guestUid: guestUid,
          guestName: guestName,
          nowMs: now,
        );
        if (kDebugMode) {
          final map = currentData is Map ? currentData : null;
          debugPrint(
            'XO_TX data=${map == null ? 'null' : 'map'} '
            'status=${map?['status']} guestUid=${map?['guestUid']} '
            'outcome=${outcome.runtimeType}',
          );
        }

        return switch (outcome) {
          RoomJoinTransactionAbort() => Transaction.abort(),
          RoomJoinTransactionSuccess(:final updatedMap) => Transaction.success(
            updatedMap,
          ),
        };
      });

      if (kDebugMode) {
        debugPrint(
          'XO_TX committed=${transactionResult.committed} '
          'valueType=${transactionResult.snapshot.value.runtimeType}',
        );
      }

      if (transactionResult.committed) {
        final val = transactionResult.snapshot.value;
        if (val is Map) {
          final updatedRoom = RoomModel.fromMap(normalized, val);
          if (!updatedRoom.isHost(guestUid)) {
            try {
              await roomRef.child('guestUid').onDisconnect().remove();
              await roomRef
                  .child('status')
                  .onDisconnect()
                  .set(RoomStatus.waitingForGuest.name);
            } catch (_) {}
          }
          return JoinRoomSuccess(updatedRoom);
        }
      }

      // If aborted / not committed: pure post-transaction state derivation
      final currentSnap = await roomRef.get();
      if (kDebugMode) {
        final map = currentSnap.value is Map ? currentSnap.value as Map : null;
        debugPrint(
          'XO_TX post exists=${currentSnap.exists} '
          'status=${map?['status']} guestUid=${map?['guestUid']}',
        );
      }
      if (!currentSnap.exists || currentSnap.value is! Map) {
        return const JoinRoomNotFound();
      }
      final latestRoom = RoomModel.fromMap(
        normalized,
        currentSnap.value as Map,
      );
      if (latestRoom.status == RoomStatus.abandoned ||
          latestRoom.status == RoomStatus.finished) {
        return const JoinRoomNotFound();
      }
      if (latestRoom.guestUid != null && latestRoom.guestUid!.isNotEmpty) {
        return const JoinRoomAlreadyFull();
      }
      if (latestRoom.status != RoomStatus.waitingForGuest) {
        return const JoinRoomError(JoinRoomFailureReason.roomUnavailable);
      }
      return const JoinRoomError(JoinRoomFailureReason.serviceUnavailable);
    } on FirebaseException catch (error) {
      debugPrint(
        'XO_JOIN error code=${error.code} message=${error.message}',
      );
      return JoinRoomError(
        _joinFailureReasonForCode(error.code, error.message),
      );
    } on TimeoutException {
      return const JoinRoomError(JoinRoomFailureReason.connection);
    } catch (error) {
      debugPrint('XO_JOIN unexpected error=${error.runtimeType} $error');
      return const JoinRoomError(JoinRoomFailureReason.serviceUnavailable);
    }
  }

  /// Starts the match atomically: writes status = inGame and game = initialState in one transaction.
  Future<StartMatchResult> startMatchAtomic({
    required String roomCode,
    required String hostUid,
  }) async {
    final normalized = RoomCode.normalize(roomCode);
    final roomRef = _db.ref('rooms/$normalized');
    StartMatchFailureReason? failureReason;
    RoomModel? updatedRoom;

    try {
      final transactionResult = await roomRef.runTransaction((currentData) {
        failureReason = null;
        // Empty local cache: let the SDK fetch the room and rerun the handler.
        if (currentData == null) {
          return Transaction.success(currentData);
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final outcome = evaluateStartMatchTransaction(
          currentData: currentData,
          normalizedCode: normalized,
          hostUid: hostUid,
          nowMs: now,
        );

        switch (outcome) {
          case StartMatchTransactionAbort(:final reason):
            failureReason = reason;
            return Transaction.abort();
          case StartMatchTransactionSuccess(
            updatedRoom: final r,
            updatedMap: final m,
          ):
            updatedRoom = r;
            return Transaction.success(m);
        }
      });

      if (transactionResult.committed && updatedRoom != null) {
        return StartMatchSuccess(updatedRoom!);
      }

      return StartMatchFailure(
        failureReason ?? StartMatchFailureReason.networkError,
      );
    } catch (_) {
      return const StartMatchFailure(StartMatchFailureReason.networkError);
    }
  }

  /// Streams live updates for [roomCode] from Firebase RTDB.
  Stream<RoomModel?> streamRoom(String roomCode) {
    try {
      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');

      return roomRef.onValue
          .map((event) {
            final val = event.snapshot.value;
            if (val == null || val is! Map) return null;
            return RoomModel.fromMap(normalized, val);
          })
          .handleError((_) => null);
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Host updates the room's board size and rounds before the match starts.
  ///
  /// The guest receives the change through [streamRoom] and sees the new
  /// settings immediately without leaving or rejoining the lobby.
  Future<UpdateRoomConfigResult> updateRoomConfig({
    required String roomCode,
    required String hostUid,
    required RoomConfig config,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      const allowedBoardSizes = {3, 6, 9, 11};
      const allowedRoundsToWin = {1, 2, 3};
      if (!allowedBoardSizes.contains(config.boardSize) ||
          !allowedRoundsToWin.contains(config.roundsToWin)) {
        return const UpdateRoomConfigNotAllowed('invalid_config');
      }

      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');
      final snapshot = await roomRef.get().timeout(timeout);
      if (!snapshot.exists || snapshot.value is! Map) {
        return const UpdateRoomConfigFailure('room_not_found');
      }

      final room = RoomModel.fromMap(normalized, snapshot.value as Map);
      if (room.hostUid != hostUid) {
        return const UpdateRoomConfigNotAllowed('not_host');
      }
      if (room.status != RoomStatus.waitingForGuest &&
          room.status != RoomStatus.ready) {
        return const UpdateRoomConfigNotAllowed('game_started');
      }

      // Re-derive the win streak from the chosen board size so the two can
      // never drift apart, and preserve any custom turn timer.
      final updatedConfig = RoomConfig.forBoardSize(
        config.boardSize,
        roundsToWin: config.roundsToWin,
      ).copyWith(turnTimeLimitSeconds: config.turnTimeLimitSeconds);

      await roomRef
          .update({
            'config': updatedConfig.toMap(),
            'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
          })
          .timeout(timeout);

      return UpdateRoomConfigSuccess(updatedConfig);
    } catch (e) {
      return UpdateRoomConfigFailure(e);
    }
  }

  /// Host triggers match start when room is ready.
  Future<void> startGame({required String roomCode, String? hostUid}) async {
    final normalized = RoomCode.normalize(roomCode);
    final roomRef = _db.ref('rooms/$normalized');
    final snapshot = await roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value;
    if (data is! Map) return;
    final room = RoomModel.fromMap(normalized, data);

    if (room.status == RoomStatus.ready) {
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

      await roomRef.update({
        'status': RoomStatus.inGame.name,
        'startedAtMs': now,
        'lastActiveMs': now,
        'game': initialGame.toMap(),
      });
    }
  }

  /// Registers the host's lobby disconnect handler: marks status abandoned and sets termination hostDisconnected.
  Future<void> registerHostLobbyDisconnect({
    required String roomCode,
    required String hostUid,
  }) async {
    try {
      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');
      await roomRef.child('status').onDisconnect().cancel();
      await roomRef.child('termination').onDisconnect().cancel();
      await _db.ref('rooms/$normalized/game/status').onDisconnect().cancel();

      final terminationMap = {
        'reason': TerminationReason.hostDisconnected.wireValue,
        'byUid': hostUid,
        'byRole': 'host',
        'message': 'انقطع اتصال المضيف، تم إغلاق الغرفة',
        'timestampMs': ServerValue.timestamp,
        'atMs': ServerValue.timestamp,
      };

      await roomRef
          .child('status')
          .onDisconnect()
          .set(RoomStatus.abandoned.name);
      await roomRef.child('termination').onDisconnect().set(terminationMap);
    } catch (_) {
      // Ignored in test/offline environments
    }
  }

  /// Registers the host's in-game disconnect handler, replacing the lobby one.
  Future<void> registerHostInGameDisconnect({
    required String roomCode,
    required String hostUid,
  }) async {
    try {
      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');
      await roomRef.child('status').onDisconnect().cancel();
      await roomRef.child('termination').onDisconnect().cancel();
      await _db.ref('rooms/$normalized/game/status').onDisconnect().cancel();

      final terminationMap = {
        'reason': TerminationReason.hostDisconnected.wireValue,
        'byUid': hostUid,
        'byRole': 'host',
        'message': 'انقطع اتصال المضيف، تم إنهاء المباراة',
        'timestampMs': ServerValue.timestamp,
        'atMs': ServerValue.timestamp,
      };

      await roomRef
          .child('status')
          .onDisconnect()
          .set(RoomStatus.abandoned.name);
      await roomRef.child('termination').onDisconnect().set(terminationMap);
      await _db
          .ref('rooms/$normalized/game/status')
          .onDisconnect()
          .set(OnlineGameStatus.matchOver.name);
    } catch (_) {
      // Ignored in test/offline environments
    }
  }

  /// Registers the guest's in-game disconnect handler, cancelling lobby slot cleanup.
  Future<void> registerGuestInGameDisconnect({
    required String roomCode,
    required String guestUid,
  }) async {
    try {
      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');
      await roomRef.child('guestUid').onDisconnect().cancel();
      await roomRef.child('status').onDisconnect().cancel();
      await roomRef.child('termination').onDisconnect().cancel();
      await _db.ref('rooms/$normalized/game/status').onDisconnect().cancel();

      final terminationMap = {
        'reason': TerminationReason.guestDisconnected.wireValue,
        'byUid': guestUid,
        'byRole': 'guest',
        'message': 'انقطع اتصال الضيف، تم إنهاء المباراة',
        'timestampMs': ServerValue.timestamp,
        'atMs': ServerValue.timestamp,
      };

      await roomRef
          .child('status')
          .onDisconnect()
          .set(RoomStatus.abandoned.name);
      await roomRef.child('termination').onDisconnect().set(terminationMap);
      await _db
          .ref('rooms/$normalized/game/status')
          .onDisconnect()
          .set(OnlineGameStatus.matchOver.name);
    } catch (_) {
      // Ignored in test/offline environments
    }
  }

  /// Cancels all disconnect handlers on the room for this client.
  Future<void> cancelDisconnectHandlers(String roomCode) async {
    try {
      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');
      await roomRef.child('status').onDisconnect().cancel();
      await roomRef.child('termination').onDisconnect().cancel();
      await _db.ref('rooms/$normalized/game/status').onDisconnect().cancel();
      await roomRef.child('termination').onDisconnect().cancel();
      await roomRef.child('guestUid').onDisconnect().cancel();
      await _db.ref('rooms/$normalized/game/status').onDisconnect().cancel();
    } catch (_) {
      // Ignored in test/offline environments
    }
  }

  /// Idempotently sets room.status = finished upon matchOver and cancels disconnect handlers.
  Future<void> markMatchFinished(String roomCode) async {
    try {
      final normalized = RoomCode.normalize(roomCode);
      await cancelDisconnectHandlers(normalized);
      final roomRef = _db.ref('rooms/$normalized');
      final snapshot = await roomRef.get();
      if (!snapshot.exists || snapshot.value is! Map) return;
      final room = RoomModel.fromMap(normalized, snapshot.value as Map);
      if (room.status == RoomStatus.inGame) {
        await roomRef.update({
          'status': RoomStatus.finished.name,
          'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (_) {}
  }

  /// Fault tolerance: writes a missing termination if room is in an inconsistent state,
  /// without overwriting an existing termination.
  Future<void> syncInferredTermination({
    required String roomCode,
    required RoomTermination termination,
  }) async {
    try {
      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');
      final snapshot = await roomRef.get();
      if (!snapshot.exists || snapshot.value is! Map) return;
      final current = RoomModel.fromMap(normalized, snapshot.value as Map);
      if (current.termination == null &&
          current.status != RoomStatus.finished) {
        final updates = <String, dynamic>{
          'rooms/$normalized/status': RoomStatus.abandoned.name,
          'rooms/$normalized/termination': termination.toMap(),
          'rooms/$normalized/lastActiveMs':
              DateTime.now().millisecondsSinceEpoch,
          'rooms/$normalized/game/status': OnlineGameStatus.matchOver.name,
        };
        await _db.ref().update(updates);
      }
    } catch (_) {}
  }

  /// Cleanly leaves the room or active match.
  ///
  /// - Host leaves lobby: Room is closed and marked abandoned with termination message
  ///   "تم إنهاء الجلسة من قبل المشرف".
  /// - Guest leaves lobby: Guest slot is vacated, room resets to `waitingForGuest`,
  ///   host stays in lobby and gets notified.
  /// - Either party leaves during match: Shared session is terminated, both sides
  ///   stop playing, and remaining side sees a clear notification of who left.
  /// - If host leaves match: Guest sees specifically "تم إنهاء الجلسة من قبل المشرف".
  ///
  /// Returns [LeaveRoomSuccess] on success, or [LeaveRoomFailure] on network error.
  Future<LeaveRoomResult> leaveRoom({
    required String roomCode,
    required String uid,
    bool? isHost,
    bool isMatch = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final normalized = RoomCode.normalize(roomCode);
      final roomRef = _db.ref('rooms/$normalized');
      final snapshot = await roomRef.get().timeout(timeout);
      if (!snapshot.exists || snapshot.value is! Map) {
        return const LeaveRoomSuccess();
      }

      final room = RoomModel.fromMap(normalized, snapshot.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;

      // Cancel onDisconnect handlers for the leaving client before writing leave event
      await cancelDisconnectHandlers(normalized);

      final effectiveIsHost = isHost ?? room.isHost(uid);

      if (effectiveIsHost) {
        if (!isMatch) {
          final termination = RoomTermination(
            reason: TerminationReason.hostLeft.wireValue,
            byUid: uid,
            byRole: 'host',
            message: 'تم إنهاء الجلسة من قبل المشرف',
            timestampMs: now,
          );

          final updates = <String, dynamic>{
            'status': RoomStatus.abandoned.name,
            'termination': termination.toMap(),
            'lastActiveMs': now,
          };

          await roomRef.update(updates).timeout(timeout);
          return const LeaveRoomSuccess();
        } else {
          // Idempotent: if already terminated, don't re-terminate
          if (room.isTerminated) {
            return const LeaveRoomSuccess();
          }

          final termination = RoomTermination(
            reason: TerminationReason.hostLeft.wireValue,
            byUid: uid,
            byRole: 'host',
            message: 'غادر المضيف المباراة، تم إنهاء الجلسة',
            timestampMs: now,
          );

          // Atomic multi-path update across room and game nodes
          final updates = <String, dynamic>{
            'rooms/$normalized/status': RoomStatus.abandoned.name,
            'rooms/$normalized/termination': termination.toMap(),
            'rooms/$normalized/lastActiveMs': now,
            'rooms/$normalized/game/status': OnlineGameStatus.matchOver.name,
          };

          await _db.ref().update(updates).timeout(timeout);
          return const LeaveRoomSuccess();
        }
      } else {
        if (!isMatch) {
          // Guest leaves waiting lobby: reopen slot, host stays waiting
          await roomRef
              .update({
                'guestUid': null,
                'guestName': null,
                'status': RoomStatus.waitingForGuest.name,
                'lastActiveMs': now,
              })
              .timeout(timeout);

          return const LeaveRoomSuccess();
        } else {
          // Idempotent: if already terminated, don't re-terminate
          if (room.isTerminated) {
            return const LeaveRoomSuccess();
          }

          final termination = RoomTermination(
            reason: TerminationReason.guestLeft.wireValue,
            byUid: uid,
            byRole: 'guest',
            message: 'غادر الضيف المباراة، تم إنهاء الجلسة',
            timestampMs: now,
          );

          // Atomic multi-path update across room and game nodes
          final updates = <String, dynamic>{
            'rooms/$normalized/status': RoomStatus.abandoned.name,
            'rooms/$normalized/termination': termination.toMap(),
            'rooms/$normalized/lastActiveMs': now,
            'rooms/$normalized/game/status': OnlineGameStatus.matchOver.name,
          };

          await _db.ref().update(updates).timeout(timeout);
          return const LeaveRoomSuccess();
        }
      }
    } catch (e) {
      return LeaveRoomFailure(e);
    }
  }

  /// Lets the host return from a finished/abandoned match to the waiting lobby,
  /// clearing previous guest info and game state, keeping the room alive for a new guest.
  Future<void> reopenLobby({required String roomCode}) async {
    final normalized = RoomCode.normalize(roomCode);
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'rooms/$normalized/status': RoomStatus.waitingForGuest.name,
      'rooms/$normalized/guestUid': null,
      'rooms/$normalized/guestName': null,
      'rooms/$normalized/termination': null,
      'rooms/$normalized/startedAtMs': null,
      'rooms/$normalized/lastActiveMs': now,
      'rooms/$normalized/game': null,
    };
    await _db.ref().update(updates);
  }
}

/// Maps a Realtime Database error code to a user-facing failure reason.
///
/// A missing or expired room is reported by RTDB as `permission-denied`
/// because its read rule evaluates to false; it must not be shown to the
/// player as a raw Firebase error.
///
/// `firebase_database` is the generic code the Android plugin uses for
/// transaction failures, so the native message is inspected as well.
JoinRoomFailureReason _joinFailureReasonForCode(String code, String? message) {
  final normalizedCode = code.toLowerCase();
  final normalizedMessage = (message ?? '').toLowerCase();

  if (normalizedCode == 'permission-denied' || normalizedCode == 'not-found') {
    return JoinRoomFailureReason.roomUnavailable;
  }
  if (normalizedCode == 'network-request-failed' ||
      normalizedCode == 'unavailable' ||
      normalizedCode == 'disconnected' ||
      normalizedCode == 'max-retries') {
    return JoinRoomFailureReason.connection;
  }
  if (normalizedCode == 'too-many-requests') {
    return JoinRoomFailureReason.tooManyRequests;
  }

  // Transaction failures arrive with the generic `firebase_database` code.
  if (normalizedMessage.contains('permission denied') ||
      normalizedMessage.contains('permission_denied')) {
    return JoinRoomFailureReason.roomUnavailable;
  }
  if (normalizedMessage.contains('network') ||
      normalizedMessage.contains('disconnected') ||
      normalizedMessage.contains('timeout') ||
      normalizedMessage.contains('timed out')) {
    return JoinRoomFailureReason.connection;
  }

  return JoinRoomFailureReason.serviceUnavailable;
}

/// Provider exposing the singleton [RoomService].
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

/// Family stream provider watching a specific room's state.
final roomStreamProvider = StreamProvider.autoDispose
    .family<RoomModel?, String>((ref, code) {
      final service = ref.watch(roomServiceProvider);
      return service.streamRoom(code);
    });
