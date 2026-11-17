import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/l10n/app_strings.dart';
import 'package:xo_neon_app/features/online/application/auth_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'package:xo_neon_app/features/online/presentation/screens/room_lobby_screen.dart';

class _FakeHostAuth extends AuthService {
  @override
  String? get currentUid => 'host_1';
}

class _FakeRoomService extends RoomService {
  _FakeRoomService({required this.room, required this.controller});

  RoomModel room;
  final StreamController<RoomModel?> controller;
  RoomConfig? lastConfig;
  UpdateRoomConfigResult? forcedResult;

  @override
  Future<UpdateRoomConfigResult> updateRoomConfig({
    required String roomCode,
    required String hostUid,
    required RoomConfig config,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    lastConfig = config;
    if (forcedResult != null) return forcedResult!;

    room = room.copyWith(config: config, lastActiveMs: 999);
    controller.add(room);
    return UpdateRoomConfigSuccess(config);
  }
}

void main() {
  const strings = AppStrings(isArabic: true);

  RoomModel buildRoom({
    RoomConfig? config,
    bool withGuest = true,
    RoomStatus status = RoomStatus.ready,
  }) {
    return RoomModel(
      code: 'TEST01',
      hostUid: 'host_1',
      hostName: 'HostUser',
      guestUid: withGuest ? 'guest_2' : null,
      guestName: withGuest ? 'GuestUser' : null,
      config: config ?? RoomConfig.standard3x3(),
      status: withGuest ? status : RoomStatus.waitingForGuest,
      createdAtMs: 100,
      lastActiveMs: 100,
    );
  }

  Widget buildLobby({
    required _FakeRoomService service,
    required StreamController<RoomModel?> controller,
    required bool isHost,
  }) {
    return ProviderScope(
      overrides: [
        roomServiceProvider.overrideWithValue(service),
        authServiceProvider.overrideWithValue(_FakeHostAuth()),
        roomStreamProvider('TEST01').overrideWith((ref) => controller.stream),
      ],
      child: MaterialApp(
        home: RoomLobbyScreen(roomCode: 'TEST01', isHost: isHost),
      ),
    );
  }

  testWidgets('host can change board size and rounds from inside the lobby',
      (tester) async {
    final controller = StreamController<RoomModel?>.broadcast();
    addTearDown(controller.close);
    final room = buildRoom();
    final service = _FakeRoomService(room: room, controller: controller);

    await tester.pumpWidget(
      buildLobby(service: service, controller: controller, isHost: true),
    );
    controller.add(room);
    await tester.pumpAndSettle();

    expect(find.text('3×3'), findsOneWidget);
    expect(find.text(strings.editRoomSettings), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('roomSettingsCard')));
    await tester.pumpAndSettle();

    expect(find.text(strings.roomSettingsTitle), findsOneWidget);
    expect(find.text(strings.roundsToWinLabel), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('room-settings-board-6')));
    await tester.tap(find.byKey(const ValueKey('room-settings-rounds-2')));
    await tester.pump();
    await tester.tap(find.text(strings.saveChanges));
    await tester.pumpAndSettle();

    expect(service.lastConfig, isNotNull);
    expect(service.lastConfig!.boardSize, 6);
    expect(service.lastConfig!.winStreak, 4);
    expect(service.lastConfig!.roundsToWin, 2);

    // The live room stream updates the summary without leaving the lobby.
    expect(find.text('6×6'), findsOneWidget);
    expect(find.text('الفائز: ٢ من ٣ جولات'), findsOneWidget);
    expect(find.text(strings.roomSettingsUpdated), findsOneWidget);
  });

  testWidgets('guest sees live settings changes and cannot edit them',
      (tester) async {
    final controller = StreamController<RoomModel?>.broadcast();
    addTearDown(controller.close);
    final room = buildRoom();
    final service = _FakeRoomService(room: room, controller: controller);

    await tester.pumpWidget(
      buildLobby(service: service, controller: controller, isHost: false),
    );
    controller.add(room);
    await tester.pumpAndSettle();

    expect(find.text(strings.editRoomSettings), findsNothing);

    final updated = room.copyWith(
      config: RoomConfig.forBoardSize(11, roundsToWin: 3),
      lastActiveMs: 300,
    );
    controller.add(updated);
    await tester.pumpAndSettle();

    expect(find.text('11×11'), findsOneWidget);
    expect(find.text('الفائز: ٣ من ٥ جولات'), findsOneWidget);
    expect(find.text(strings.guestUpdatedRoomSettings), findsOneWidget);
  });

  testWidgets('host sees an error and keeps old settings when update fails',
      (tester) async {
    final controller = StreamController<RoomModel?>.broadcast();
    addTearDown(controller.close);
    final room = buildRoom();
    final service = _FakeRoomService(room: room, controller: controller)
      ..forcedResult = const UpdateRoomConfigFailure('network');

    await tester.pumpWidget(
      buildLobby(service: service, controller: controller, isHost: true),
    );
    controller.add(room);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('roomSettingsCard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-settings-board-9')));
    await tester.pump();
    await tester.tap(find.text(strings.saveChanges));
    await tester.pumpAndSettle();

    expect(find.text(strings.roomSettingsUpdateFailed), findsOneWidget);
    expect(find.text('3×3'), findsOneWidget);
    expect(find.text('9×9'), findsNothing);
  });
}
