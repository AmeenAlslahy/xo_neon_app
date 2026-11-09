import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/models/player.dart';
import 'package:xo_neon_app/features/online/application/online_match_service.dart';
import 'package:xo_neon_app/features/online/domain/models/online_game_state.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'package:xo_neon_app/features/online/presentation/screens/online_game_board_screen.dart';

void main() {
  testWidgets('OnlineGameBoardScreen renders HUD, scores, and active grid',
      (tester) async {
    final room = RoomModel(
      code: 'A7K9X2',
      hostUid: 'host_1',
      hostName: 'CyberHost',
      guestUid: 'guest_2',
      guestName: 'CyberGuest',
      config: RoomConfig.standard3x3(),
      createdAtMs: 100,
      lastActiveMs: 100,
    );

    const initialGame = OnlineGameState(
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
          onlineGameStreamProvider(room.code)
              .overrideWith((ref) => Stream.value(initialGame)),
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

    // Verify HUD elements
    expect(find.text('3x3 - A7K9X2'), findsOneWidget);
    expect(find.text('X'), findsWidgets);
    expect(find.text('O'), findsWidgets);
    expect(find.text('0'), findsWidgets); // initial scores
  });
}
