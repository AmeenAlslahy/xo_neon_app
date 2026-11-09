import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import '../application/fake_system_move_port.dart';
import 'package:xo_neon_app/features/game/application/match_providers.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_board_screen.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_setup_screen.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/neon_x_widget.dart';

void main() {
  Widget buildTestableWidget({bool isArabic = true}) {
    return ProviderScope(
      overrides: [
        // Never spawn real isolates from widget tests.
        systemMovePortProvider.overrideWithValue(const FirstEmptySystemMovePort()),
      ],
      child: MaterialApp(
        theme: NeonTheme.darkTheme,
        locale: Locale(isArabic ? 'ar' : 'en'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const GameSetupScreen(),
      ),
    );
  }

  group('GameSetupScreen Widget Tests', () {
    testWidgets('renders grid presets, rounds selector (1, 3, 5), and timer options', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      expect(find.text('إعداد المباراة'), findsOneWidget);
      expect(find.text('اختر حجم الرقعة'), findsOneWidget);

      // Verify the 4 authorized presets
      expect(find.text('٣×٣ (كلاسيكي)'), findsOneWidget);
      expect(find.text('٦×٦ (تكتيكي)'), findsOneWidget);
      expect(find.text('٩×٩ (احترافي)'), findsOneWidget);
      expect(find.text('١١×١١ (أسطوري)'), findsOneWidget);

      // Verify Total Rounds section (1, 3, 5)
      expect(find.text('عدد الجولات'), findsOneWidget);
      expect(find.text('جولة واحدة'), findsOneWidget);
      expect(find.text('٣ جولات (افتراضي)'), findsOneWidget);
      expect(find.text('٥ جولات'), findsOneWidget);

      // Verify Chess-Clock Timer section
      expect(find.text('المؤقت (ساعة شطرنج)'), findsOneWidget);
      expect(find.text('بدون مؤقت'), findsOneWidget);
      expect(find.text('دقيقة لكل لاعب'), findsOneWidget);
      expect(find.text('٣ دقائق لكل لاعب'), findsOneWidget);
      expect(find.text('٥ دقائق لكل لاعب'), findsOneWidget);
      expect(find.text('وقت مخصص'), findsOneWidget);

      // Verify Start Match button
      expect(find.text('بدء المباراة'), findsOneWidget);
    });

    testWidgets('selecting 6x6 preset and 5 rounds navigates to GameBoardScreen with exact configuration', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      // Tap 6x6 option
      await tester.tap(find.text('٦×٦ (تكتيكي)'));
      await tester.pumpAndSettle();

      // Tap 5 rounds option (scroll it into view first)
      await tester.ensureVisible(find.text('٥ جولات'));
      await tester.tap(find.text('٥ جولات'));
      await tester.pumpAndSettle();

      // Scroll and Tap Start Match button
      await tester.ensureVisible(find.text('بدء المباراة'));
      await tester.tap(find.text('بدء المباراة'));
      await tester.pumpAndSettle();

      // Verify GameBoardScreen is pushed
      expect(find.byType(GameBoardScreen), findsOneWidget);
      expect(find.text('٦×٦ (تكتيكي)'), findsOneWidget);      expect(find.text('٦×٦ (تكتيكي)'), findsOneWidget);
    });

    testWidgets('selecting custom timer reveals bounds and duration', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      // Scroll to timer section if needed
      await tester.ensureVisible(find.text('وقت مخصص'));
      await tester.tap(find.text('وقت مخصص'));
      await tester.pumpAndSettle();

      // Verify bounds are displayed
      expect(find.text('من ١٥ ثانية إلى ١٥ دقيقة'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('system mode reveals level and mark options; local mode hides them', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      // Default: local two players — system options hidden.
      expect(find.text('ضد النظام'), findsOneWidget);
      expect(find.text('سهل'), findsNothing);
      expect(find.text('متوسط'), findsNothing);
      expect(find.text('صعب'), findsNothing);
      expect(find.text('تلعب X'), findsNothing);
      expect(find.text('تلعب O'), findsNothing);

      // Selecting the system mode reveals level + mark options.
      await tester.tap(find.text('ضد النظام'));
      await tester.pumpAndSettle();
      expect(find.text('سهل'), findsOneWidget);
      expect(find.text('متوسط'), findsOneWidget);
      expect(find.text('صعب'), findsOneWidget);
      expect(find.text('تلعب X'), findsOneWidget);
      expect(find.text('تلعب O'), findsOneWidget);

      // Back to local: hidden again.
      await tester.tap(find.text('لاعبان محليًا'));
      await tester.pumpAndSettle();
      expect(find.text('سهل'), findsNothing);
      expect(find.text('تلعب X'), findsNothing);
    });

    testWidgets('selecting system mode with an O mark starts a match the system opens', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ضد النظام'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تلعب O'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('بدء المباراة'));
      await tester.tap(find.text('بدء المباراة'));
      await tester.pumpAndSettle();

      expect(find.byType(GameBoardScreen), findsOneWidget);
      // The system (X) plays the opening move automatically.
      expect(find.byType(NeonXWidget), findsNWidgets(2), reason: 'board mark + HUD');
      expect(find.text('اللاعب O'), findsOneWidget, reason: 'the human O is next');
    });

    testWidgets('system mode reveals auto difficulty progression switch and allows toggling', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ضد النظام'));
      await tester.pumpAndSettle();

      expect(find.text('التدرج التلقائي للصعوبة'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
    });
  });
}
