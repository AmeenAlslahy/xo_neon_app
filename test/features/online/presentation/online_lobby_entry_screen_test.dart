import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/online/presentation/screens/create_room_screen.dart';
import 'package:xo_neon_app/features/online/presentation/screens/join_room_screen.dart';
import 'package:xo_neon_app/features/online/presentation/screens/online_lobby_entry_screen.dart';

void main() {
  testWidgets('OnlineLobbyEntryScreen renders Create and Join room cards',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnlineLobbyEntryScreen(),
        ),
      ),
    );

    expect(find.byType(OnlineLobbyEntryScreen), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);

    // Tap Create Room card -> navigates to CreateRoomScreen
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(CreateRoomScreen), findsOneWidget);
  });

  testWidgets('OnlineLobbyEntryScreen navigates to JoinRoomScreen',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnlineLobbyEntryScreen(),
        ),
      ),
    );

    // Tap Join Room card -> navigates to JoinRoomScreen
    await tester.tap(find.byIcon(Icons.login_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(JoinRoomScreen), findsOneWidget);
  });
}
