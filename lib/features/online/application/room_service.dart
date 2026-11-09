import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase_options.dart';
import '../domain/models/room_code.dart';
import '../domain/models/room_config.dart';
import '../domain/models/room_model.dart';

/// Sealed result of an attempt to join an existing online room.
sealed class JoinRoomResult {
  const JoinRoomResult();
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

class JoinRoomError extends JoinRoomResult {
  const JoinRoomError(this.message);
  final String message;
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

    // When host disconnects while still waiting for a guest, mark room abandoned
    try {
      await roomRef.child('status').onDisconnect().set(RoomStatus.abandoned.name);
    } catch (_) {
      // Ignored in test/offline environments
    }

    return room;
  }

  /// Attempts to join a room.
  Future<JoinRoomResult> joinRoom({
    required String rawCode,
    required String guestUid,
    String guestName = 'Player 2',
  }) async {
    final normalized = RoomCode.normalize(rawCode);
    if (!RoomCode.isValid(normalized)) {
      return const JoinRoomError('Invalid room code format');
    }

    final roomRef = _db.ref('rooms/$normalized');
    final snapshot = await roomRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return const JoinRoomNotFound();
    }

    final data = snapshot.value;
    if (data is! Map) {
      return const JoinRoomNotFound();
    }

    final currentRoom = RoomModel.fromMap(normalized, data);

    if (currentRoom.status == RoomStatus.abandoned ||
        currentRoom.status == RoomStatus.finished) {
      return const JoinRoomNotFound();
    }

    // If current player is the host, let them enter as host
    if (currentRoom.isHost(guestUid)) {
      return JoinRoomSuccess(currentRoom);
    }

    // If current player is already the joined guest, let them re-enter
    if (currentRoom.isGuest(guestUid)) {
      return JoinRoomSuccess(currentRoom);
    }

    // Check if slot is occupied by someone else
    if (currentRoom.guestUid != null && currentRoom.guestUid!.isNotEmpty) {
      return const JoinRoomAlreadyFull();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = currentRoom.copyWith(
      guestUid: guestUid,
      guestName: guestName,
      status: RoomStatus.ready,
      lastActiveMs: now,
    );

    // Update the room in RTDB
    await roomRef.update({
      'guestUid': guestUid,
      'guestName': guestName,
      'status': RoomStatus.ready.name,
      'lastActiveMs': now,
    });

    // When guest disconnects while in lobby, clean up their slot
    try {
      await roomRef.child('guestUid').onDisconnect().remove();
      await roomRef
          .child('status')
          .onDisconnect()
          .set(RoomStatus.waitingForGuest.name);
    } catch (_) {
      // Ignored in test/offline environments
    }

    return JoinRoomSuccess(updated);
  }

  /// Streams live updates for [roomCode] from Firebase RTDB.
  Stream<RoomModel?> streamRoom(String roomCode) {
    final normalized = RoomCode.normalize(roomCode);
    final roomRef = _db.ref('rooms/$normalized');

    return roomRef.onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return null;
      return RoomModel.fromMap(normalized, val);
    });
  }

  /// Host triggers match start when room is ready.
  Future<void> startGame({
    required String roomCode,
    String? hostUid,
  }) async {
    final normalized = RoomCode.normalize(roomCode);
    final roomRef = _db.ref('rooms/$normalized');
    final snapshot = await roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value;
    if (data is! Map) return;
    final room = RoomModel.fromMap(normalized, data);

    if (room.status == RoomStatus.ready) {
      await roomRef.update({
        'status': RoomStatus.inGame.name,
        'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Cleanly leaves the room.
  Future<void> leaveRoom({
    required String roomCode,
    required String uid,
  }) async {
    final normalized = RoomCode.normalize(roomCode);
    final roomRef = _db.ref('rooms/$normalized');
    final snapshot = await roomRef.get();
    if (!snapshot.exists || snapshot.value is! Map) return;

    final room = RoomModel.fromMap(normalized, snapshot.value as Map);

    if (room.isHost(uid)) {
      // Host left: mark room abandoned
      await roomRef.update({
        'status': RoomStatus.abandoned.name,
        'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
      });
    } else if (room.isGuest(uid)) {
      // Guest left: reopen slot
      await roomRef.update({
        'guestUid': null,
        'guestName': null,
        'status': RoomStatus.waitingForGuest.name,
        'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
}

/// Provider exposing the singleton [RoomService].
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

/// Family stream provider watching a specific room's state.
final roomStreamProvider =
    StreamProvider.autoDispose.family<RoomModel?, String>((ref, code) {
  final service = ref.watch(roomServiceProvider);
  return service.streamRoom(code);
});
