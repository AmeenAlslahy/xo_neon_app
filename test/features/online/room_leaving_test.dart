import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/l10n/app_strings.dart';
import 'package:xo_neon_app/core/l10n/locale_providers.dart';
import 'package:xo_neon_app/core/widgets/neon_button.dart';
import 'package:xo_neon_app/features/game/domain/models/cell_position.dart';
import 'package:xo_neon_app/features/game/domain/models/player.dart';
import 'package:xo_neon_app/features/online/application/connection_status_provider.dart';
import 'package:xo_neon_app/features/online/application/online_match_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/logic/online_transactions.dart';
import 'package:xo_neon_app/features/online/domain/models/online_game_state.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'package:xo_neon_app/features/online/presentation/screens/online_game_board_screen.dart';
import 'package:xo_neon_app/features/online/presentation/screens/room_lobby_screen.dart';

class MockRoomService extends RoomService {
  MockRoomService({
    this.leaveResult = const LeaveRoomSuccess(),
  });

  LeaveRoomResult leaveResult;
  int leaveCallCount = 0;
  String? lastLeftRoomCode;
  String? lastLeftUid;
  bool? lastIsMatch;
  int markMatchFinishedCount = 0;
  int cancelDisconnectCount = 0;
  int registerHostLobbyDisconnectCount = 0;
  int registerHostInGameDisconnectCount = 0;
  bool failStartGame = false;
  RoomModel? currentRoom;

  @override
  Future<RoomModel?> getRoom(String roomCode) async => currentRoom;

  @override
  Future<void> registerHostLobbyDisconnect({
    required String roomCode,
    required String hostUid,
  }) async {
    registerHostLobbyDisconnectCount++;
  }

  int startMatchAtomicCount = 0;

  @override
  Future<StartMatchResult> startMatchAtomic({
    required String roomCode,
    required String hostUid,
  }) async {
    startMatchAtomicCount++;
    if (failStartGame) {
      return const StartMatchFailure(StartMatchFailureReason.networkError);
    }
    return StartMatchSuccess(
      currentRoom?.copyWith(status: RoomStatus.inGame) ??
          RoomModel(
            code: roomCode,
            hostUid: hostUid,
            hostName: 'Host',
            config: RoomConfig.standard3x3(),
            status: RoomStatus.inGame,
            createdAtMs: 100,
            lastActiveMs: 100,
          ),
    );
  }

  @override
  Future<void> startGame({
    required String roomCode,
    String? hostUid,
  }) async {
    if (failStartGame) {
      throw Exception('Network timeout starting match');
    }
  }

  @override
  Future<LeaveRoomResult> leaveRoom({
    required String roomCode,
    required String uid,
    bool? isHost,
    bool isMatch = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    leaveCallCount++;
    lastLeftRoomCode = roomCode;
    lastLeftUid = uid;
    lastIsMatch = isMatch;
    return leaveResult;
  }

  @override
  Future<void> markMatchFinished(String roomCode) async {
    markMatchFinishedCount++;
  }

  @override
  Future<void> cancelDisconnectHandlers(String roomCode) async {
    cancelDisconnectCount++;
  }

  @override
  Future<void> registerHostInGameDisconnect({
    required String roomCode,
    required String hostUid,
  }) async {
    registerHostInGameDisconnectCount++;
  }

  @override
  Future<void> registerGuestInGameDisconnect({
    required String roomCode,
    required String guestUid,
  }) async {}

  @override
  Future<void> syncInferredTermination({
    required String roomCode,
    required RoomTermination termination,
  }) async {}
}

class MockOnlineMatchService extends OnlineMatchService {
  int submitMoveCount = 0;

  @override
  Future<SubmitMoveResult> submitMove({
    required RoomModel room,
    required Position position,
    required Player player,
  }) async {
    submitMoveCount++;
    return SubmitMoveSuccess(
      OnlineGameState(
        currentRound: 1,
        currentTurn: player.other,
        hostScore: 0,
        guestScore: 0,
        moves: [
          OnlineMove(
            row: position.row,
            col: position.col,
            player: player,
            timestampMs: 100,
          ),
        ],
        lastUpdatedMs: 100,
      ),
    );
  }
}

void main() {
  group('Room Termination Model & RoomService Unit Tests', () {
    test('RoomTermination model serialization roundtrip', () {
      const term = RoomTermination(
        reason: 'host_left',
        byUid: 'host_123',
        byRole: 'host',
        message: 'تم إنهاء الجلسة من قبل المشرف',
        timestampMs: 12345678,
      );

      final map = term.toMap();
      final reconstructed = RoomTermination.fromMap(map);

      expect(reconstructed, term);
      expect(reconstructed.isHost, isTrue);
      expect(reconstructed.isGuest, isFalse);
      expect(reconstructed.message, 'تم إنهاء الجلسة من قبل المشرف');
    });

    test('RoomModel with termination marks isTerminated true', () {
      final room = RoomModel(
        code: 'A1B2C3',
        hostUid: 'host_1',
        hostName: 'HostPlayer',
        config: RoomConfig.standard3x3(),
        createdAtMs: 100,
        lastActiveMs: 100,
        termination: const RoomTermination(
          reason: 'host_left',
          byUid: 'host_1',
          byRole: 'host',
          message: 'تم إنهاء الجلسة من قبل المشرف',
          timestampMs: 100,
        ),
      );

      expect(room.isTerminated, isTrue);
      final map = room.toMap();
      expect(map['termination'], isNotNull);
      final reconstructed = RoomModel.fromMap('A1B2C3', map);
      expect(reconstructed.isTerminated, isTrue);
      expect(reconstructed.termination?.message, 'تم إنهاء الجلسة من قبل المشرف');
    });
  });

  group('Lobby Leaving Behavior Tests', () {
    testWidgets('Guest in lobby sees "تم إنهاء الجلسة من قبل المشرف" when host abandons room', (tester) async {
      final streamController = StreamController<RoomModel?>.broadcast();

      final baseRoom = RoomModel(
        code: 'TEST01',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.ready,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('TEST01').overrideWith((ref) => streamController.stream),
          ],
          child: const MaterialApp(
            home: RoomLobbyScreen(
              roomCode: 'TEST01',
              isHost: false, // Guest's perspective
            ),
          ),
        ),
      );

      // Initial ready lobby
      streamController.add(baseRoom);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('HostUser'), findsOneWidget);
      expect(find.text('GuestUser'), findsOneWidget);

      // Host leaves: room status becomes abandoned with termination
      final abandonedRoom = baseRoom.copyWith(
        status: RoomStatus.abandoned,
        termination: const RoomTermination(
          reason: 'host_left',
          byUid: 'host_id',
          byRole: 'host',
          message: 'تم إنهاء الجلسة من قبل المشرف',
          timestampMs: 200,
        ),
      );

      streamController.add(abandonedRoom);
      await tester.pump();
      await tester.pumpAndSettle();

      // Guest MUST see specifically "تم إنهاء الجلسة من قبل المشرف"
      expect(find.text('تم إنهاء الجلسة من قبل المشرف'), findsOneWidget);
      expect(find.text('العودة للرئيسية'), findsOneWidget);

      await streamController.close();
    });

    testWidgets('Host in lobby receives one notification when guest vacates slot', (tester) async {
      final streamController = StreamController<RoomModel?>.broadcast();

      final fullRoom = RoomModel(
        code: 'TEST02',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.ready,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('TEST02').overrideWith((ref) => streamController.stream),
          ],
          child: const MaterialApp(
            home: RoomLobbyScreen(
              roomCode: 'TEST02',
              isHost: true, // Host's perspective
            ),
          ),
        ),
      );

      // Initial state: room full with guest
      streamController.add(fullRoom);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Guest leaves: guest slot is vacated and status becomes waitingForGuest
      final vacatedRoom = fullRoom.copyWith(
        clearGuest: true,
        status: RoomStatus.waitingForGuest,
      );

      streamController.add(vacatedRoom);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Host sees one distinct notification
      final strings = const AppStrings(isArabic: true);
      expect(find.text(strings.guestLeftLobby), findsOneWidget);

      // Firing same vacated state again does not duplicate the alert
      streamController.add(vacatedRoom);
      await tester.pump();
      expect(find.text(strings.guestLeftLobby), findsOneWidget);

      await streamController.close();
    });

    testWidgets('Network failure on leaving room shows clear retry dialog and does not claim success', (tester) async {
      final mockService = MockRoomService(
        leaveResult: const LeaveRoomFailure('Network timeout'),
      );

      final room = RoomModel(
        code: 'TEST03',
        hostUid: 'host_id',
        hostName: 'HostUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.waitingForGuest,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(mockService),
            roomStreamProvider('TEST03').overrideWith((ref) => Stream.value(room)),
          ],
          child: const MaterialApp(
            home: RoomLobbyScreen(
              roomCode: 'TEST03',
              isHost: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap back button (leave room)
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(milliseconds: 100));

      final strings = const AppStrings(isArabic: true);
      expect(find.text(strings.leaveRoomConfirm), findsOneWidget);

      // Confirm leave
      await tester.tap(find.widgetWithText(NeonButton, strings.leaveRoom).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Network failed: Error dialog must be shown with Retry & Leave Anyway options
      expect(find.text(strings.leaveErrorConnection), findsOneWidget);
      expect(find.text(strings.retry), findsOneWidget);
      expect(find.text(strings.leaveAnyway), findsOneWidget);

      // Screen was NOT popped silently
      expect(find.byType(RoomLobbyScreen), findsOneWidget);
    });
  });

  group('In-Match Leaving Behavior Tests', () {
    testWidgets('Host leaving during match shows guest "تم إنهاء الجلسة من قبل المشرف" and halts match', (tester) async {
      final roomStream = StreamController<RoomModel?>.broadcast();
      final gameStream = StreamController<OnlineGameState?>.broadcast();

      final room = RoomModel(
        code: 'MATCH1',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const activeGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('MATCH1').overrideWith((ref) => roomStream.stream),
            onlineGameStreamProvider('MATCH1').overrideWith((ref) => gameStream.stream),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: false, // Guest's perspective
            ),
          ),
        ),
      );

      roomStream.add(room);
      gameStream.add(activeGame);
      await tester.pump();
      await tester.pumpAndSettle();

      // Host leaves during match
      final terminatedRoom = room.copyWith(
        status: RoomStatus.abandoned,
        termination: const RoomTermination(
          reason: 'host_left',
          byUid: 'host_id',
          byRole: 'host',
          message: 'تم إنهاء الجلسة من قبل المشرف',
          timestampMs: 300,
        ),
      );

      roomStream.add(terminatedRoom);
      await tester.pump();
      await tester.pumpAndSettle();

      // Guest must see specifically "تم إنهاء الجلسة من قبل المشرف"
      expect(find.text('تم إنهاء الجلسة من قبل المشرف'), findsOneWidget);
      expect(find.text('العودة للرئيسية'), findsOneWidget);

      await roomStream.close();
      await gameStream.close();
    });

    testWidgets('Guest leaving during match shows host "غادر الضيف المباراة، تم إنهاء الجلسة"', (tester) async {
      final roomStream = StreamController<RoomModel?>.broadcast();
      final gameStream = StreamController<OnlineGameState?>.broadcast();

      final room = RoomModel(
        code: 'MATCH2',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const activeGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('MATCH2').overrideWith((ref) => roomStream.stream),
            onlineGameStreamProvider('MATCH2').overrideWith((ref) => gameStream.stream),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: true, // Host's perspective
            ),
          ),
        ),
      );

      roomStream.add(room);
      gameStream.add(activeGame);
      await tester.pump();
      await tester.pumpAndSettle();

      // Guest leaves during match
      final terminatedRoom = room.copyWith(
        status: RoomStatus.abandoned,
        termination: const RoomTermination(
          reason: 'guest_left',
          byUid: 'guest_id',
          byRole: 'guest',
          message: 'غادر الضيف المباراة، تم إنهاء الجلسة',
          timestampMs: 300,
        ),
      );

      roomStream.add(terminatedRoom);
      await tester.pump();
      await tester.pumpAndSettle();

      // Host sees notification identifying that guest left
      final strings = const AppStrings(isArabic: true);
      expect(find.text(strings.guestLeftMatch), findsOneWidget);
      expect(find.text('العودة للرئيسية'), findsOneWidget);

      await roomStream.close();
      await gameStream.close();
    });

    testWidgets('Temporary network reconnection is distinct from intentional leave', (tester) async {
      final room = RoomModel(
        code: 'MATCH3',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const activeGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 100,
      );

      final container = ProviderContainer(
        overrides: [
          roomStreamProvider('MATCH3').overrideWith((ref) => Stream.value(room)),
          onlineGameStreamProvider('MATCH3').overrideWith((ref) => Stream.value(activeGame)),
        ],
      );
      addTearDown(container.dispose);

      // Simulate network state: reconnecting
      container.read(connectionStatusProvider.notifier).setStatus(ConnectionStatus.reconnecting);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final strings = container.read(stringsProvider);

      // Reconnecting banner is visible
      expect(find.text(strings.connectionReconnecting), findsOneWidget);

      // Must NOT be classified as an intentional termination
      expect(find.text('تم إنهاء الجلسة من قبل المشرف'), findsNothing);
      expect(find.text(strings.guestLeftMatch), findsNothing);
    });

    testWidgets('Guest disconnect during match (waitingForGuest + game playing) does not leave host hanging, shows disconnect message and blocks moves', (tester) async {
      final roomStream = StreamController<RoomModel?>.broadcast();
      final gameStream = StreamController<OnlineGameState?>.broadcast();
      final mockMatchService = MockOnlineMatchService();

      final room = RoomModel(
        code: 'MATCH_DISC',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const activeGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('MATCH_DISC').overrideWith((ref) => roomStream.stream),
            onlineGameStreamProvider('MATCH_DISC').overrideWith((ref) => gameStream.stream),
            onlineMatchServiceProvider.overrideWithValue(mockMatchService),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: true,
            ),
          ),
        ),
      );

      roomStream.add(room);
      gameStream.add(activeGame);
      await tester.pump();
      await tester.pumpAndSettle();

      // Guest disconnects: socket drops and guest lobby onDisconnect fires (status becomes waitingForGuest, guestUid removed)
      final droppedRoom = room.copyWith(
        status: RoomStatus.waitingForGuest,
        clearGuest: true,
      );

      roomStream.add(droppedRoom);
      await tester.pump();
      await tester.pumpAndSettle();

      final strings = const AppStrings(isArabic: true);
      // Host immediately sees disconnect message (NOT "غادر")
      expect(find.text(strings.guestDisconnectedMatch), findsOneWidget);
      expect(find.text(strings.guestLeftMatch), findsNothing);
      expect(find.text('العودة للرئيسية'), findsOneWidget);

      // Verify moves are blocked / tapping cell does NOT submit move
      await tester.tap(find.byType(InkWell).first, warnIfMissed: false);
      await tester.pump();
      expect(mockMatchService.submitMoveCount, 0);

      await roomStream.close();
      await gameStream.close();
    });

    testWidgets('Host disconnect during match shows guest "انقطع اتصال المضيف، تم إنهاء المباراة"', (tester) async {
      final roomStream = StreamController<RoomModel?>.broadcast();
      final gameStream = StreamController<OnlineGameState?>.broadcast();

      final room = RoomModel(
        code: 'MATCH_HOST_DISC',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const activeGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('MATCH_HOST_DISC').overrideWith((ref) => roomStream.stream),
            onlineGameStreamProvider('MATCH_HOST_DISC').overrideWith((ref) => gameStream.stream),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: false, // Guest perspective
            ),
          ),
        ),
      );

      roomStream.add(room);
      gameStream.add(activeGame);
      await tester.pump();
      await tester.pumpAndSettle();

      // Host disconnects
      final disconnectedRoom = room.copyWith(
        status: RoomStatus.abandoned,
        termination: const RoomTermination(
          reason: 'host_disconnected',
          byUid: 'host_id',
          byRole: 'host',
          message: 'انقطع اتصال المضيف، تم إنهاء المباراة',
          timestampMs: 300,
        ),
      );

      roomStream.add(disconnectedRoom);
      await tester.pump();
      await tester.pumpAndSettle();

      final strings = const AppStrings(isArabic: true);
      expect(find.text(strings.hostDisconnectedMatch), findsOneWidget);
      expect(find.text(strings.hostLeftMatch), findsNothing);

      await roomStream.close();
      await gameStream.close();
    });

    testWidgets('Return home reaches the root screen (HomeScreen), popping all intermediary screens', (tester) async {
      final room = RoomModel(
        code: 'MATCH_ROOT',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.abandoned,
        createdAtMs: 100,
        lastActiveMs: 100,
        termination: const RoomTermination(
          reason: 'host_left',
          byUid: 'host_id',
          byRole: 'host',
          message: 'تم إنهاء الجلسة',
          timestampMs: 100,
        ),
      );

      const activeGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 100,
      );

      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('MATCH_ROOT').overrideWith((ref) => Stream.value(room)),
            onlineGameStreamProvider('MATCH_ROOT').overrideWith((ref) => Stream.value(activeGame)),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Text('Root HomeScreen')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Root HomeScreen'), findsOneWidget);

      // Push intermediate lobby screen
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Intermediate Online Lobby')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Intermediate Online Lobby'), findsOneWidget);

      // Push game board screen
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => OnlineGameBoardScreen(
            room: room,
            isHost: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "العودة للرئيسية"
      await tester.tap(find.text('العودة للرئيسية'));
      await tester.pumpAndSettle();

      // Must pop all the way to root HomeScreen, NOT stop at Online Lobby!
      expect(find.text('Root HomeScreen'), findsOneWidget);
      expect(find.text('Intermediate Online Lobby'), findsNothing);
    });

    testWidgets('matchOver triggers markMatchFinished and cancels disconnect handlers', (tester) async {
      final mockRoomService = MockRoomService();
      final room = RoomModel(
        code: 'MATCH_FINISH',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const matchOverGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 1,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.matchOver,
        lastUpdatedMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(mockRoomService),
            roomStreamProvider('MATCH_FINISH').overrideWith((ref) => Stream.value(room)),
            onlineGameStreamProvider('MATCH_FINISH').overrideWith((ref) => Stream.value(matchOverGame)),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(mockRoomService.markMatchFinishedCount, 1);
    });

    testWidgets('Consecutive rebuilds after matchOver do NOT invoke markMatchFinished more than once in the same session', (tester) async {
      final mockRoomService = MockRoomService();
      final room = RoomModel(
        code: 'MATCH_FINISH_ONCE',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      final gameController = StreamController<OnlineGameState?>.broadcast();
      addTearDown(gameController.close);

      final roomController = StreamController<RoomModel?>.broadcast();
      addTearDown(roomController.close);

      const matchOverGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 1,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.matchOver,
        roundWinner: Player.x,
        lastUpdatedMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(mockRoomService),
            roomStreamProvider('MATCH_FINISH_ONCE').overrideWith((ref) => roomController.stream),
            onlineGameStreamProvider('MATCH_FINISH_ONCE').overrideWith((ref) => gameController.stream),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: true,
            ),
          ),
        ),
      );

      // Emit room and matchOver
      roomController.add(room);
      gameController.add(matchOverGame);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(mockRoomService.markMatchFinishedCount, 1);

      // 5 consecutive state updates / rebuilds
      for (int i = 1; i <= 5; i++) {
        gameController.add(matchOverGame.copyWith(lastUpdatedMs: 100 + i));
        await tester.pump();
        await tester.pumpAndSettle();
      }

      // Must remain exactly 1 call across all rebuilds
      expect(mockRoomService.markMatchFinishedCount, 1);
    });

    testWidgets('Confirming leave twice does NOT execute leaveRoom twice', (tester) async {
      final mockRoomService = MockRoomService();
      final room = RoomModel(
        code: 'MATCH_DOUBLE_LEAVE',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const activeGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(mockRoomService),
            roomStreamProvider('MATCH_DOUBLE_LEAVE').overrideWith((ref) => Stream.value(room)),
            onlineGameStreamProvider('MATCH_DOUBLE_LEAVE').overrideWith((ref) => Stream.value(activeGame)),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap close button in AppBar to open confirmation dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('مغادرة الغرفة'), findsWidgets);

      // Confirm leave
      await tester.tap(find.widgetWithText(NeonButton, 'مغادرة الغرفة'));
      await tester.pumpAndSettle();

      expect(mockRoomService.leaveCallCount, 1);
    });

    testWidgets('Compound state: matchOver + termination + abandoned displays match result first without termination overlay', (tester) async {
      final room = RoomModel(
        code: 'MATCH_COMPOUND',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.abandoned,
        createdAtMs: 100,
        lastActiveMs: 100,
        termination: const RoomTermination(
          reason: 'guest_disconnected',
          byUid: 'guest_id',
          byRole: 'guest',
          message: 'انقطع اتصال الضيف',
          timestampMs: 150,
        ),
      );

      const naturalMatchOverGame = OnlineGameState(
        currentRound: 2,
        currentTurn: Player.o,
        hostScore: 2,
        guestScore: 0,
        moves: [],
        roundWinner: Player.x,
        status: OnlineGameStatus.matchOver,
        lastUpdatedMs: 140,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider('MATCH_COMPOUND').overrideWith((ref) => Stream.value(room)),
            onlineGameStreamProvider('MATCH_COMPOUND').overrideWith((ref) => Stream.value(naturalMatchOverGame)),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Must display match victory message and session options (rematch, settings, end session)
      expect(find.text('نهاية المباراة! الفائز: X'), findsOneWidget);
      expect(find.text('إعادة اللعب'), findsOneWidget);
      expect(find.text('تغيير الإعدادات'), findsOneWidget);
      expect(find.text('إنهاء الجلسة'), findsOneWidget);

      // Must NOT display termination overlay
      expect(find.byIcon(Icons.exit_to_app_rounded), findsNothing);
      expect(find.text('انقطع اتصال الضيف'), findsNothing);
    });

    testWidgets('Non-moving player (guest) also triggers markMatchFinished upon observing matchOver', (tester) async {
      final mockRoomService = MockRoomService();
      final room = RoomModel(
        code: 'MATCH_FINISH_GUEST',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.inGame,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      const matchOverGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 1,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.matchOver,
        roundWinner: Player.x,
        lastUpdatedMs: 100,
      );

      // Render screen for guest (isHost: false, didn't make the winning move)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(mockRoomService),
            roomStreamProvider('MATCH_FINISH_GUEST').overrideWith((ref) => Stream.value(room)),
            onlineGameStreamProvider('MATCH_FINISH_GUEST').overrideWith((ref) => Stream.value(matchOverGame)),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(mockRoomService.markMatchFinishedCount, 1);
    });

    testWidgets('StartGame failure re-registers host lobby disconnect handler so room does not stay ready on disconnect', (tester) async {
      final mockRoomService = MockRoomService()..failStartGame = true;
      final room = RoomModel(
        code: 'LOBBY_FAIL_START',
        hostUid: 'host_id',
        hostName: 'HostUser',
        guestUid: 'guest_id',
        guestName: 'GuestUser',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.ready,
        createdAtMs: 100,
        lastActiveMs: 100,
      );
      mockRoomService.currentRoom = room;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(mockRoomService),
            roomStreamProvider('LOBBY_FAIL_START').overrideWith((ref) => Stream.value(room)),
          ],
          child: const MaterialApp(
            home: RoomLobbyScreen(
              roomCode: 'LOBBY_FAIL_START',
              isHost: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap start game button
      final startBtn = find.widgetWithText(NeonButton, 'بدء المباراة');
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Verify in-game disconnect was cancelled and lobby disconnect was restored
      expect(mockRoomService.registerHostInGameDisconnectCount, 1);
      expect(mockRoomService.cancelDisconnectCount, greaterThanOrEqualTo(1));
      expect(mockRoomService.registerHostLobbyDisconnectCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
