import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import 'package:xo_neon_app/core/l10n/locale_providers.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_setup_screen.dart';
import 'package:xo_neon_app/features/game/presentation/screens/home_screen.dart';

void main() {
  Widget buildTestableWidget({bool isArabic = true}) {
    return ProviderScope(
      overrides: [
        // Pin the locale only when a non-default language is requested; the
        // language-toggle test uses the real LocaleController.
        if (!isArabic) localeInitialProvider.overrideWithValue(false),
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
        home: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen Widget Tests', () {
    testWidgets('renders Arabic brand title, subtitle, and mode cards', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      // Check title and subtitle in Arabic
      expect(find.text('XO نيون'), findsWidgets);
      expect(find.text('لعبة الإكس أو بألوان النيون العصرية'), findsOneWidget);

      // Check Local Play card
      expect(find.text('لعب محلي'), findsOneWidget);
      expect(find.text('لاعبان يتنافسان على نفس الهاتف'), findsOneWidget);

      // Check Online Friend card with coming-soon badge
      expect(find.text('اللعب مع صديق'), findsOneWidget);
      expect(find.text('قريباً (مرحلة الأونلاين)'), findsOneWidget);
    });

    testWidgets('navigates to GameSetupScreen when Local Play card is tapped', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      final localPlayCard = find.text('لعب محلي');
      await tester.tap(localPlayCard);
      await tester.pumpAndSettle();

      // Verify GameSetupScreen is displayed
      expect(find.byType(GameSetupScreen), findsOneWidget);
      expect(find.text('إعداد المباراة'), findsOneWidget);
    });

    testWidgets('toggling language switches between Arabic and English text', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Initially Arabic
      expect(find.text('لعب محلي'), findsOneWidget);

      // Tap language switch button — driven by localeProvider via LocaleController
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Now English
      expect(find.text('Local Play'), findsOneWidget);
      expect(find.text('Play with a Friend'), findsOneWidget);
      expect(find.text('Coming Soon (Online Phase)'), findsOneWidget);
    });
  });
}
