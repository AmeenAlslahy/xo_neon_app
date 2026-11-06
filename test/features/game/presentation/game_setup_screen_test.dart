import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_board_screen.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_setup_screen.dart';

void main() {
  Widget buildTestableWidget({bool isArabic = true}) {
    return MaterialApp(
      theme: NeonTheme.darkTheme,
      locale: Locale(isArabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: GameSetupScreen(isArabic: isArabic),
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

      // Tap 5 rounds option
      await tester.tap(find.text('٥ جولات'));
      await tester.pumpAndSettle();

      // Scroll and Tap Start Match button
      await tester.ensureVisible(find.text('بدء المباراة'));
      await tester.tap(find.text('بدء المباراة'));
      await tester.pumpAndSettle();

      // Verify GameBoardScreen is pushed
      expect(find.byType(GameBoardScreen), findsOneWidget);
      expect(find.text('٦×٦ (تكتيكي)'), findsOneWidget);
      expect(find.text('الجولة ١ من ٥'), findsOneWidget);
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
  });
}
