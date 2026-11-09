import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/online/presentation/widgets/room_code_display.dart';

void main() {
  testWidgets('RoomCodeDisplay renders 6-character code with copy button',
      (tester) async {
    bool wasCopied = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RoomCodeDisplay(
              code: 'A7K9X2',
              onCopied: () => wasCopied = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('A7K9X2'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(wasCopied, isTrue);
  });
}
