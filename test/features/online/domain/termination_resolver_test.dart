import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/l10n/app_strings.dart';
import 'package:xo_neon_app/features/game/domain/models/player.dart';
import 'package:xo_neon_app/features/online/domain/logic/termination_resolver.dart';
import 'package:xo_neon_app/features/online/domain/models/online_game_state.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';

void main() {
  group('resolveTermination Unit Tests', () {
    const stringsAr = AppStrings(isArabic: true);
    const stringsEn = AppStrings(isArabic: false);

    final standardConfig = RoomConfig.standard3x3();

    final baseRoom = RoomModel(
      code: 'TEST01',
      hostUid: 'host_1',
      hostName: 'HostPlayer',
      guestUid: 'guest_2',
      guestName: 'GuestPlayer',
      config: standardConfig,
      status: RoomStatus.inGame,
      createdAtMs: 100,
      lastActiveMs: 100,
    );

    const playingGame = OnlineGameState(
      currentRound: 1,
      currentTurn: Player.x,
      hostScore: 0,
      guestScore: 0,
      moves: [],
      status: OnlineGameStatus.playing,
      lastUpdatedMs: 100,
    );

    test('Null room returns isTerminated: false', () {
      final res = resolveTermination(null, playingGame);
      expect(res.isTerminated, isFalse);
    });

    test('Normal in-progress game returns isTerminated: false', () {
      final res = resolveTermination(baseRoom, playingGame);
      expect(res.isTerminated, isFalse);
    });

    test('Explicit termination on room is always prioritized', () {
      final terminatedRoom = baseRoom.copyWith(
        status: RoomStatus.abandoned,
        termination: const RoomTermination(
          reason: 'host_left',
          byUid: 'host_1',
          byRole: 'host',
          message: 'Host manually quit',
          timestampMs: 100,
        ),
      );

      final res = resolveTermination(terminatedRoom, playingGame);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.hostLeft);
      expect(res.byRole, 'host');
      expect(res.byUid, 'host_1');
    });

    test('game.status == matchOver is a match completion, NOT a termination', () {
      const matchOverGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 1,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.matchOver,
        lastUpdatedMs: 100,
      );

      final roomInGame = baseRoom.copyWith(status: RoomStatus.inGame);
      final res = resolveTermination(roomInGame, matchOverGame);

      expect(res.isTerminated, isFalse);
    });

    test('Compound state: matchOver with natural winner + termination + abandoned prioritizes match completion', () {
      const naturalMatchOverGame = OnlineGameState(
        currentRound: 2,
        currentTurn: Player.o,
        hostScore: 2,
        guestScore: 0,
        moves: [],
        roundWinner: Player.x,
        status: OnlineGameStatus.matchOver,
        lastUpdatedMs: 200,
      );

      final terminatedAbandonedRoom = baseRoom.copyWith(
        status: RoomStatus.abandoned,
        termination: const RoomTermination(
          reason: 'guest_disconnected',
          byUid: 'guest_2',
          byRole: 'guest',
          message: 'انقطع اتصال الضيف',
          timestampMs: 210,
        ),
      );

      final res = resolveTermination(terminatedAbandonedRoom, naturalMatchOverGame);
      expect(res.isTerminated, isFalse,
          reason: 'Natural match completion must take precedence over delayed disconnect/termination');
    });

    test('inter-round active state (roundWon): waitingForGuest or guestUid null infers guestDisconnected', () {
      const roundWonGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 1,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.roundWon,
        roundWinner: Player.x,
        lastUpdatedMs: 150,
      );

      final roomDropped = baseRoom.copyWith(
        status: RoomStatus.waitingForGuest,
        clearGuest: true,
      );

      final res = resolveTermination(roomDropped, roundWonGame);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.guestDisconnected);
      expect(res.byRole, 'guest');
    });

    test('inter-round active state (roundDraw): room abandoned with null guest infers guestDisconnected', () {
      const roundDrawGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.o,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.roundDraw,
        lastUpdatedMs: 150,
      );

      final roomAbandonedNoGuest = baseRoom.copyWith(
        status: RoomStatus.abandoned,
        clearGuest: true,
      );

      final res = resolveTermination(roomAbandonedNoGuest, roundDrawGame);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.guestDisconnected);
    });

    test('game playing + room waitingForGuest infers guestDisconnected', () {
      final roomDropped = baseRoom.copyWith(
        status: RoomStatus.waitingForGuest,
        clearGuest: true,
      );

      final res = resolveTermination(roomDropped, playingGame);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.guestDisconnected);
      expect(res.byRole, 'guest');
    });

    test('game playing + guestUid null infers guestDisconnected', () {
      final roomNoGuest = baseRoom.copyWith(
        status: RoomStatus.inGame,
        clearGuest: true,
      );

      final res = resolveTermination(roomNoGuest, playingGame);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.guestDisconnected);
      expect(res.byRole, 'guest');
    });

    test('game playing + room abandoned without guest infers guestDisconnected', () {
      final roomAbandonedNoGuest = baseRoom.copyWith(
        status: RoomStatus.abandoned,
        clearGuest: true,
      );

      final res = resolveTermination(roomAbandonedNoGuest, playingGame);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.guestDisconnected);
    });

    test('game playing + room abandoned with guest infers roomClosed', () {
      final roomAbandoned = baseRoom.copyWith(
        status: RoomStatus.abandoned,
      );

      final res = resolveTermination(roomAbandoned, playingGame);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.roomClosed);
    });

    test('room abandoned without active game returns roomClosed', () {
      final roomAbandoned = baseRoom.copyWith(
        status: RoomStatus.abandoned,
      );

      final res = resolveTermination(roomAbandoned, null);
      expect(res.isTerminated, isTrue);
      expect(res.reason, TerminationReason.roomClosed);
    });

    group('Message localization distinguishing "left" from "disconnected"', () {
      test('hostLeft message is distinguished from hostDisconnected', () {
        const hostLeft = ResolvedTermination(
          isTerminated: true,
          reason: TerminationReason.hostLeft,
          byRole: 'host',
        );

        const hostDisconnected = ResolvedTermination(
          isTerminated: true,
          reason: TerminationReason.hostDisconnected,
          byRole: 'host',
        );

        // Guest sees:
        final guestMsgLeftAr = hostLeft.getLocalizedMessage(stringsAr, isHost: false);
        final guestMsgDiscAr = hostDisconnected.getLocalizedMessage(stringsAr, isHost: false);
        expect(guestMsgLeftAr, contains('غادر المضيف'));
        expect(guestMsgDiscAr, contains('انقطع اتصال المضيف'));
        expect(guestMsgLeftAr, isNot(equals(guestMsgDiscAr)));

        final guestMsgLeftEn = hostLeft.getLocalizedMessage(stringsEn, isHost: false);
        final guestMsgDiscEn = hostDisconnected.getLocalizedMessage(stringsEn, isHost: false);
        expect(guestMsgLeftEn, contains('Host left'));
        expect(guestMsgDiscEn, contains('Host disconnected'));
        expect(guestMsgLeftEn, isNot(equals(guestMsgDiscEn)));
      });

      test('guestLeft message is distinguished from guestDisconnected', () {
        const guestLeft = ResolvedTermination(
          isTerminated: true,
          reason: TerminationReason.guestLeft,
          byRole: 'guest',
        );

        const guestDisconnected = ResolvedTermination(
          isTerminated: true,
          reason: TerminationReason.guestDisconnected,
          byRole: 'guest',
        );

        // Host sees:
        final hostMsgLeftAr = guestLeft.getLocalizedMessage(stringsAr, isHost: true);
        final hostMsgDiscAr = guestDisconnected.getLocalizedMessage(stringsAr, isHost: true);
        expect(hostMsgLeftAr, contains('غادر الضيف'));
        expect(hostMsgDiscAr, contains('انقطع اتصال الضيف'));
        expect(hostMsgLeftAr, isNot(equals(hostMsgDiscAr)));

        final hostMsgLeftEn = guestLeft.getLocalizedMessage(stringsEn, isHost: true);
        final hostMsgDiscEn = guestDisconnected.getLocalizedMessage(stringsEn, isHost: true);
        expect(hostMsgLeftEn, contains('Guest left'));
        expect(hostMsgDiscEn, contains('Guest disconnected'));
        expect(hostMsgLeftEn, isNot(equals(hostMsgDiscEn)));
      });

      test('roomClosed message', () {
        const roomClosed = ResolvedTermination(
          isTerminated: true,
          reason: TerminationReason.roomClosed,
        );

        expect(roomClosed.getLocalizedMessage(stringsAr, isHost: true), contains('تم إغلاق الغرفة'));
        expect(roomClosed.getLocalizedMessage(stringsEn, isHost: false), contains('Room was closed'));
      });
    });
  });
}
