import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/online/presentation/widgets/player_slot_card.dart';

void main() {
  testWidgets('PlayerSlotCard displays occupied state with player name and mark',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerSlotCard(
            roleTitle: 'Host (X)',
            isHost: true,
            playerName: 'CyberPlayer',
            isOccupied: true,
            isCurrentPlayer: true,
            waitingText: 'Waiting...',
            youBadgeText: 'You',
          ),
        ),
      ),
    );

    expect(find.text('Host (X)'), findsOneWidget);
    expect(find.text('CyberPlayer'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('PlayerSlotCard displays waiting state with progress indicator',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerSlotCard(
            roleTitle: 'Guest (O)',
            isHost: false,
            playerName: null,
            isOccupied: false,
            isCurrentPlayer: false,
            waitingText: 'Waiting for friend...',
            youBadgeText: 'You',
          ),
        ),
      ),
    );

    expect(find.text('Guest (O)'), findsOneWidget);
    expect(find.text('Waiting for friend...'), findsOneWidget);
    expect(find.text('O'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
