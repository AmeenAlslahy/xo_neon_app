import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/widgets/neon_button.dart';
import 'package:xo_neon_app/features/online/presentation/screens/join_room_screen.dart';

void main() {
  NeonButton joinButton(WidgetTester tester) =>
      tester.widget<NeonButton>(find.byType(NeonButton));

  testWidgets('Join button enables when a valid code is typed manually',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: JoinRoomScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(joinButton(tester).isDisabled, isTrue);
    expect(joinButton(tester).onPressed, isNull);

    // Regression: manual typing must rebuild the screen so the derived
    // canJoin state (and therefore the button) becomes active.
    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.pump();

    expect(joinButton(tester).isDisabled, isFalse);
    expect(joinButton(tester).onPressed, isNotNull);
  });

  testWidgets('Join button disables again when the code becomes incomplete',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: JoinRoomScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.pump();
    expect(joinButton(tester).isDisabled, isFalse);

    await tester.enterText(find.byType(TextField), 'ABC23');
    await tester.pump();

    expect(joinButton(tester).isDisabled, isTrue);
    expect(joinButton(tester).onPressed, isNull);
  });

  testWidgets('Join button is active immediately for a prefilled deep-link code',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: JoinRoomScreen(initialCode: 'h7j2k9')),
      ),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'H7J2K9');
    expect(joinButton(tester).isDisabled, isFalse);
    expect(joinButton(tester).onPressed, isNotNull);
  });
}
