import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/l10n/app_strings.dart';
import 'package:xo_neon_app/core/widgets/neon_button.dart';
import 'package:xo_neon_app/features/game/domain/models/player.dart';
import 'package:xo_neon_app/features/online/application/online_match_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/models/online_game_state.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'package:xo_neon_app/features/online/presentation/screens/online_game_board_screen.dart';

class FakeMatchService extends OnlineMatchService {
  int rematchCount = 0;
  RoomConfig? lastNewConfig;

  @override
  Future<void> rematch({
    required RoomModel room,
    RoomConfig? newConfig,
  }) async {
    rematchCount++;
    lastNewConfig = newConfig;
  }
}

class FakeRoomService extends RoomService {
  int reopenLobbyCount = 0;

  @override
  Future<void> reopenLobby({required String roomCode}) async {
    reopenLobbyCount++;
  }

  @override
  Future<LeaveRoomResult> leaveRoom({
    required String roomCode,
    required String uid,
    bool? isHost,
    bool isMatch = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return const LeaveRoomSuccess();
  }

  @override
  Future<void> markMatchFinished(String roomCode) async {}

  @override
  Future<void> cancelDisconnectHandlers(String roomCode) async {}
}

void main() {
  group('Rematch and Change Settings Online Tests', () {
    testWidgets('MatchOver displays Rematch, Settings, and End Session buttons',
        (tester) async {
      final fakeMatch = FakeMatchService();
      final fakeRoom = FakeRoomService();
      final room = RoomModel(
        code: 'REMATCH1',
        hostUid: 'host123',
        hostName: 'HostPlayer',
        guestUid: 'guest456',
        guestName: 'GuestPlayer',
        status: RoomStatus.inGame,
        createdAtMs: 1000,
        lastActiveMs: 1000,
        config: const RoomConfig(
          boardSize: 3,
          winStreak: 3,
          roundsToWin: 1,
          turnTimeLimitSeconds: 30,
        ),
      );

      final matchOverGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.o,
        hostScore: 1,
        guestScore: 0,
        moves: const [
          OnlineMove(row: 0, col: 0, player: Player.x, timestampMs: 100),
          OnlineMove(row: 1, col: 0, player: Player.o, timestampMs: 200),
          OnlineMove(row: 0, col: 1, player: Player.x, timestampMs: 300),
          OnlineMove(row: 1, col: 1, player: Player.o, timestampMs: 400),
          OnlineMove(row: 0, col: 2, player: Player.x, timestampMs: 500),
        ],
        status: OnlineGameStatus.matchOver,
        roundWinner: Player.x,
        lastUpdatedMs: 600,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineMatchServiceProvider.overrideWithValue(fakeMatch),
            roomServiceProvider.overrideWithValue(fakeRoom),
            roomStreamProvider('REMATCH1').overrideWith((ref) => Stream.value(room)),
            onlineGameStreamProvider('REMATCH1')
                .overrideWith((ref) => Stream.value(matchOverGame)),
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

      final strings = AppStrings(isArabic: true);

      // Verify all 3 options are displayed
      expect(find.text(strings.replayMatch), findsOneWidget);
      expect(find.text(strings.changeMatchSettings), findsOneWidget);
      expect(find.text(strings.endSession), findsOneWidget);

      // Tap Replay Match
      await tester.tap(find.widgetWithText(NeonButton, strings.replayMatch));
      await tester.pumpAndSettle();

      expect(fakeMatch.rematchCount, 1);
    });

    testWidgets('Guest sees message when clicking Change Settings',
        (tester) async {
      final fakeMatch = FakeMatchService();
      final fakeRoom = FakeRoomService();
      final room = RoomModel(
        code: 'REMATCH2',
        hostUid: 'host123',
        hostName: 'HostPlayer',
        guestUid: 'guest456',
        guestName: 'GuestPlayer',
        status: RoomStatus.inGame,
        createdAtMs: 1000,
        lastActiveMs: 1000,
        config: const RoomConfig(
          boardSize: 3,
          winStreak: 3,
          roundsToWin: 1,
          turnTimeLimitSeconds: 30,
        ),
      );

      final matchOverGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.o,
        hostScore: 1,
        guestScore: 0,
        moves: const [],
        status: OnlineGameStatus.matchOver,
        roundWinner: Player.x,
        lastUpdatedMs: 600,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineMatchServiceProvider.overrideWithValue(fakeMatch),
            roomServiceProvider.overrideWithValue(fakeRoom),
            roomStreamProvider('REMATCH2').overrideWith((ref) => Stream.value(room)),
            onlineGameStreamProvider('REMATCH2')
                .overrideWith((ref) => Stream.value(matchOverGame)),
          ],
          child: MaterialApp(
            home: OnlineGameBoardScreen(
              room: room,
              isHost: false, // GUEST
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      final strings = AppStrings(isArabic: true);

      // Tap Change Settings as guest
      await tester.tap(find.widgetWithText(NeonButton, strings.changeMatchSettings));
      await tester.pump();

      // Guest sees only host can change settings snackbar
      expect(find.text(strings.onlyHostCanChangeSettings), findsOneWidget);
    });
  });
}
