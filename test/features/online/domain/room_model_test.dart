import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';

void main() {
  group('RoomConfig Domain Model', () {
    test('forBoardSize sets expected default streaks', () {
      final config3 = RoomConfig.forBoardSize(3);
      expect(config3.boardSize, 3);
      expect(config3.winStreak, 3);

      final config6 = RoomConfig.forBoardSize(6);
      expect(config6.boardSize, 6);
      expect(config6.winStreak, 4);

      final config9 = RoomConfig.forBoardSize(9);
      expect(config9.boardSize, 9);
      expect(config9.winStreak, 5);

      final config11 = RoomConfig.forBoardSize(11);
      expect(config11.boardSize, 11);
      expect(config11.winStreak, 6);
    });

    test('serialization round-trip to/from Map', () {
      const config = RoomConfig(
        boardSize: 6,
        winStreak: 4,
        roundsToWin: 2,
        turnTimeLimitSeconds: 20,
      );

      final map = config.toMap();
      final reloaded = RoomConfig.fromMap(map);

      expect(reloaded, equals(config));
    });
  });

  group('RoomModel Domain Model', () {
    test('lifecycle getters and participant checks', () {
      final room = RoomModel(
        code: 'A7K9X2',
        hostUid: 'host_123',
        hostName: 'NeonHost',
        guestUid: null,
        guestName: null,
        config: RoomConfig.standard3x3(),
        createdAtMs: 1000,
        lastActiveMs: 1000,
      );

      expect(room.isFull, isFalse);
      expect(room.isReady, isFalse);
      expect(room.isHost('host_123'), isTrue);
      expect(room.isGuest('host_123'), isFalse);
      expect(room.isParticipant('host_123'), isTrue);
      expect(room.isParticipant('stranger'), isFalse);

      final fullRoom = room.copyWith(
        guestUid: 'guest_456',
        guestName: 'NeonGuest',
        status: RoomStatus.ready,
      );

      expect(fullRoom.isFull, isTrue);
      expect(fullRoom.isReady, isTrue);
      expect(fullRoom.isGuest('guest_456'), isTrue);
      expect(fullRoom.isParticipant('guest_456'), isTrue);
    });

    test('serialization round-trip to/from Map', () {
      final room = RoomModel(
        code: 'A7K9X2',
        hostUid: 'host_123',
        hostName: 'NeonHost',
        guestUid: 'guest_456',
        guestName: 'NeonGuest',
        config: RoomConfig.forBoardSize(6, roundsToWin: 3),
        status: RoomStatus.ready,
        createdAtMs: 1234567,
        lastActiveMs: 1234567,
      );

      final map = room.toMap();
      final reloaded = RoomModel.fromMap('A7K9X2', map);

      expect(reloaded.code, 'A7K9X2');
      expect(reloaded.hostUid, 'host_123');
      expect(reloaded.guestUid, 'guest_456');
      expect(reloaded.status, RoomStatus.ready);
      expect(reloaded.config.boardSize, 6);
      expect(reloaded.config.winStreak, 4);
      expect(reloaded.config.roundsToWin, 3);
    });
  });
}
