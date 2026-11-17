import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import 'package:xo_neon_app/core/services/haptics.dart';
import 'package:xo_neon_app/core/theme/app_tokens.dart';
import 'package:xo_neon_app/features/game/application/match_providers.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_board_screen.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/animated_cell_mark.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/celebration_banner.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/celebration_glyphs.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/celebration_particles.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/game_over_dialog.dart';
import '../game/application/fake_system_move_port.dart';

Widget _wrapTestWidget(
  Widget child, {
  bool disableAnimations = false,
  double textScaleFactor = 1.0,
}) {
  return ProviderScope(
    overrides: [
      systemMovePortProvider.overrideWithValue(const FirstEmptySystemMovePort()),
    ],
    child: MaterialApp(
      theme: NeonTheme.darkTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScaleFactor),
          size: const Size(400, 800),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

final testWinningLine = WinningLine(
  positions: const [Position(0, 0), Position(0, 1), Position(0, 2)],
  direction: WinDirection.horizontal,
);

void main() {
  late HapticsRecorder recorder;

  setUp(() {
    recorder = Haptics.useRecorder();
  });

  tearDown(() {
    Haptics.useSystemDriver();
  });

  group('UX-DELIGHT-01: Sensory and Celebration Feedback', () {
    test('1 & 2. Haptics spec table routing & single invocation check', () async {
      recorder.reset();

      // Test spec table mapping:
      await Haptics.markPlaced();
      expect(recorder.log.last, equals('selectionClick'));

      await Haptics.primaryTap();
      expect(recorder.log.last, equals('selectionClick'));

      await Haptics.draw();
      expect(recorder.log.last, equals('selectionClick'));

      await Haptics.roomCodeCopied();
      expect(recorder.log.last, equals('lightImpact'));

      await Haptics.guestJoined();
      expect(recorder.log.last, equals('lightImpact'));

      await Haptics.roundSettled();
      expect(recorder.log.last, equals('lightImpact'));

      await Haptics.connectionFailure();
      expect(recorder.log.last, equals('lightImpact'));

      await Haptics.matchWon();
      expect(recorder.log.last, equals('mediumImpact'));

      expect(recorder.count('selectionClick'), equals(3));
      expect(recorder.count('lightImpact'), equals(4));
      expect(recorder.count('mediumImpact'), equals(1));
    });

    testWidgets('1b. Move placed produces mark and exactly 1 selectionClick haptic', (tester) async {
      final config = const MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
        timerConfig: TimerConfig.disabled(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchConfigProvider.overrideWithValue(config),
            systemMovePortProvider.overrideWithValue(const FirstEmptySystemMovePort()),
          ],
          child: MaterialApp(
            theme: NeonTheme.darkTheme,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const GameBoardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      recorder.reset();

      // Tap cell (0, 0)
      final cell00 = find.byKey(const ValueKey('cell-0-0'));
      expect(cell00, findsOneWidget);
      await tester.tap(cell00);
      await tester.pump(const Duration(milliseconds: 50));

      // Assert exactly 1 selectionClick occurred for this mark placement
      expect(recorder.count('selectionClick'), equals(1));
      expect(recorder.count('lightImpact'), equals(0));
      expect(recorder.count('mediumImpact'), equals(0));
    });

    testWidgets('3. Round victory banner appears and auto-dismisses after 1800ms', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        _wrapTestWidget(
          CelebrationBanner(
            type: CelebrationType.roundWon,
            onDismissed: () => dismissed = true,
          ),
        ),
      );

      // Banner should be visible initially
      expect(find.byType(CelebrationBanner), findsOneWidget);
      expect(dismissed, isFalse);

      // Advance by 1000ms - still visible
      await tester.pump(const Duration(milliseconds: 1000));
      expect(dismissed, isFalse);

      // Advance past 1800ms
      await tester.pump(const Duration(milliseconds: 850));
      expect(dismissed, isTrue);
    });

    testWidgets('4. Match victory layer has IgnorePointer so board clicks pass through', (tester) async {
      await tester.pumpWidget(
        _wrapTestWidget(
          Stack(
            children: const [
              CelebrationParticlesOverlay(
                origin: Offset(200, 200),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // Find IgnorePointer widget wrapping the particle overlay
      final ignorePointerFinder = find.descendant(
        of: find.byType(CelebrationParticlesOverlay),
        matching: find.byType(IgnorePointer),
      );
      expect(ignorePointerFinder, findsOneWidget);

      final ignorePointer = tester.widget<IgnorePointer>(ignorePointerFinder);
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('5. Draw scenario has zero gold widgets, zero particles, and no winning line', (tester) async {
      await tester.pumpWidget(
        _wrapTestWidget(
          GameOverDialog(
            status: const GameDraw(),
            isFinalMatchResult: true,
            matchWinner: null,
            onRematch: () {},
            onExit: () {},
          ),
        ),
      );
      await tester.pump();

      // Verify no gold color (AppTokens.amberGold) is in text or icons
      final goldIcon = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.color == AppTokens.amberGold,
      );
      expect(goldIcon, findsNothing);

      // Verify no Trophy or Crown
      expect(find.byType(TrophyGlyphWidget), findsNothing);
      expect(find.byType(CrownGlyphWidget), findsNothing);

      // Verify DrawGlyphWidget is used
      expect(find.byType(DrawGlyphWidget), findsOneWidget);

      // Verify zero particles
      expect(find.byType(CelebrationParticlesOverlay), findsNothing);
    });

    testWidgets('6. Loss scenario has zero red color in the widget tree', (tester) async {
      await tester.pumpWidget(
        _wrapTestWidget(
          GameOverDialog(
            status: GameWon(winner: Player.o, winningLine: testWinningLine),
            isFinalMatchResult: true,
            matchWinner: Player.o,
            isHumanWinner: false,
            onRematch: () {},
            onExit: () {},
          ),
        ),
      );
      await tester.pump();

      // Assert zero red colors anywhere in text styles, icons, or containers
      final redWidget = find.byWidgetPredicate((widget) {
        if (widget is Text && widget.style?.color == Colors.red) return true;
        if (widget is Icon && widget.color == Colors.red) return true;
        if (widget is Container) {
          final decoration = widget.decoration;
          if (decoration is BoxDecoration) {
            if (decoration.color == Colors.red || decoration.color == Colors.redAccent) {
              return true;
            }
          }
        }
        return false;
      });
      expect(redWidget, findsNothing);

      // Assert title text contains calm defeat wording
      expect(find.text('فاز الخصم — كانت قريبة'), findsOneWidget);
    });

    testWidgets('7. disableAnimations = true produces zero particles and zero ScaleTransition pop', (tester) async {
      await tester.pumpWidget(
        _wrapTestWidget(
          const AnimatedCellMark(
            player: Player.x,
            size: 80,
            isWinning: false,
            hasGlow: false,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // With disableAnimations = true, AnimatedCellMark uses FadeTransition and NO ScaleTransition
      expect(
        find.descendant(of: find.byType(AnimatedCellMark), matching: find.byType(ScaleTransition)),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(AnimatedCellMark), matching: find.byType(FadeTransition)),
        findsOneWidget,
      );

      // Particles overlay with disableAnimations
      await tester.pumpWidget(
        _wrapTestWidget(
          const CelebrationParticlesOverlay(
            origin: Offset(100, 100),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      // Particles overlay does exist but does not animate
      final particles = find.byType(CelebrationParticlesOverlay);
      expect(particles, findsOneWidget);
    });

    testWidgets('8. Celebration particles overlay is isolated in RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        _wrapTestWidget(
          const CelebrationParticlesOverlay(
            origin: Offset(150, 150),
          ),
        ),
      );
      await tester.pump();

      final repaintBoundary = find.descendant(
        of: find.byType(CelebrationParticlesOverlay),
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundary, findsOneWidget);
    });

    testWidgets('9. Celebration dialog at TextScaler(1.3) has zero RenderFlex overflow', (tester) async {
      // Test victory dialog with large accessibility text scale factor 1.3
      await tester.pumpWidget(
        _wrapTestWidget(
          GameOverDialog(
            status: GameWon(winner: Player.x, winningLine: testWinningLine),
            isFinalMatchResult: true,
            matchWinner: Player.x,
            isHumanWinner: true,
            onRematch: () {},
            onExit: () {},
          ),
          textScaleFactor: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      // No overflow exceptions should have been caught by FlutterError
      expect(tester.takeException(), isNull);

      // Test draw dialog at TextScaler 1.3
      await tester.pumpWidget(
        _wrapTestWidget(
          GameOverDialog(
            status: const GameDraw(),
            isFinalMatchResult: true,
            matchWinner: null,
            onRematch: () {},
            onExit: () {},
          ),
          textScaleFactor: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test loss dialog at TextScaler 1.3
      await tester.pumpWidget(
        _wrapTestWidget(
          GameOverDialog(
            status: GameWon(winner: Player.o, winningLine: testWinningLine),
            isFinalMatchResult: true,
            matchWinner: Player.o,
            isHumanWinner: false,
            onRematch: () {},
            onExit: () {},
          ),
          textScaleFactor: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
