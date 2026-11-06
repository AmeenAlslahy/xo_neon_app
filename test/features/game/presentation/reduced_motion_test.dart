import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/widgets/neon_button.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/cell_widget.dart';

void main() {
  group('Accessibility & Reduced Motion Tests', () {
    testWidgets('NeonButton respects disableAnimations setting without scale latency', (tester) async {
      var wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: NeonButton(
                label: 'Test Button',
                onPressed: () => wasPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Button'));
      await tester.pump();

      expect(wasPressed, isTrue);
    });

    testWidgets('CellWidget handles taps cleanly under reduced motion mode', (tester) async {
      var cellTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SizedBox(
                width: 100,
                height: 100,
                child: CellWidget(
                  position: const Position(0, 0),
                  onTap: () => cellTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CellWidget));
      await tester.pump();

      expect(cellTapped, isTrue);
    });
  });
}

