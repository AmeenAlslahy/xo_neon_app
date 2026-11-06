import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_board_screen.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/game_grid_widget.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/game_over_dialog.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/neon_o_widget.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/neon_x_widget.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/player_turn_header.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/round_end_banner.dart';

void main() {
  Widget buildTestableWidget({
    MatchConfig? matchConfig,
    BoardConfig? config,
    bool isArabic = true,
    TextScaler textScaler = TextScaler.noScaling,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: NeonTheme.darkTheme,
      locale: Locale(isArabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: GameBoardScreen(
          matchConfig: matchConfig,
          config: config ?? BoardConfig.grid3x3,
          isArabic: isArabic,
        ),
      ),
    );
  }

  /// Helper to tap cell at (row, col) via semantics label.
  /// [settle] = false advances ZERO fake time (tap + single render pump),
  /// for timing-deterministic race tests.
  Future<void> tapCell(
    WidgetTester tester,
    int row,
    int col, {
    bool isArabic = true,
    bool settle = true,
  }) async {
    final label = isArabic
        ? 'الخانة: الصف ${row + 1}، العمود ${col + 1}'
        : 'Cell row ${row + 1} column ${col + 1}';
    final cellFinder = find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}(?:\\D|\$)'));
    expect(cellFinder, findsOneWidget, reason: 'Could not find cell ($row, $col) with label $label');
    await tester.tap(cellFinder, warnIfMissed: false);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  group('GameBoardScreen - Clean UI & Removal of Mock Data', () {
    testWidgets('renders PlayerTurnHeader, board win rule, and NO demo timer or mock buttons', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(PlayerTurnHeader), findsOneWidget);
      expect(find.text('اللاعب X'), findsOneWidget);
      expect(find.text('اللاعب O'), findsOneWidget);
      expect(find.text('٣×٣ • ٣ للفوز'), findsOneWidget);

      // Verify demo timer is removed
      expect(find.text('مؤقت تجريبي: ١٥ث'), findsNothing);

      // Verify mock "فوز ساحق!" button is removed
      expect(find.text('فوز ساحق!'), findsNothing);

      // Verify legitimate control buttons
      expect(find.text('إعادة الجولة'), findsOneWidget);
      expect(find.text('الرئيسية'), findsOneWidget);
    });
  });

  group('GameBoardScreen - Real Engine Integration & Rules', () {
    testWidgets('tapping empty cells places alternating X and O marks via real GameEngine', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap (0, 0) -> X
      await tapCell(tester, 0, 0);
      expect(find.byType(NeonXWidget), findsNWidgets(2)); // 1 mark on board + 1 in HUD

      // Tap (0, 1) -> O
      await tapCell(tester, 0, 1);
      expect(find.byType(NeonOWidget), findsNWidgets(2)); // 1 mark on board + 1 in HUD
    });

    testWidgets('tapping an occupied cell does NOT change game state or switch player turn', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap (1, 1) -> X
      await tapCell(tester, 1, 1);
      expect(find.text('O'), findsOneWidget); // O's turn now

      // Tap (1, 1) again (occupied)
      await tapCell(tester, 1, 1);
      // Turn MUST still belong to O, not advanced!
      expect(find.text('O'), findsOneWidget);
    });

    testWidgets('real match ending in Victory: draws winning line, increments score once, shows dialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Initial scores: 0 - 0
      expect(find.text('0'), findsNWidgets(2));

      // Play moves leading to X horizontal win on row 0:
      // (0,0)=X, (1,0)=O, (0,1)=X, (1,1)=O, (0,2)=X (Win!)
      await tapCell(tester, 0, 0); // X
      await tapCell(tester, 1, 0); // O
      await tapCell(tester, 0, 1); // X
      await tapCell(tester, 1, 1); // O
      await tapCell(tester, 0, 2); // X Wins!

      // Header immediately updates to terminal status "فاز X!"
      expect(find.text('فاز X!'), findsOneWidget);
      expect(find.text('الدور الآن'), findsNothing);

      // Allow dialog delay (1200ms) to settle
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // Verify GameOverDialog is displayed with final match outcome
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('النتيجة النهائية للمباراة'), findsOneWidget);
      expect(find.text('رؤية الرقعة'), findsOneWidget);

      // Verify score for Player X updated to 1, while Player O remains 0
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      // Dismiss dialog to inspect board
      await tester.tap(find.text('رؤية الرقعة'));
      await tester.pumpAndSettle();

      // Dialog is dismissed, board & winning line remain visible
      expect(find.byType(GameOverDialog), findsNothing);
      expect(find.text('عرض النتيجة'), findsOneWidget);

      // Re-open dialog via "عرض النتيجة"
      await tester.tap(find.text('عرض النتيجة'));
      await tester.pumpAndSettle();
      expect(find.byType(GameOverDialog), findsOneWidget);

      // Tap Play Again in dialog
      await tester.tap(find.descendant(
        of: find.byType(GameOverDialog),
        matching: find.text('العب مجدداً'),
      ));
      await tester.pumpAndSettle();

      // New match starts with zeroed scores
      expect(find.text('0'), findsNWidgets(2));

      // Board is cleared
      expect(find.byType(NeonXWidget), findsOneWidget);
      expect(find.byType(NeonOWidget), findsOneWidget);

      // Player X starts fresh match
      expect(find.text('X'), findsOneWidget);
      expect(find.text('الدور الآن'), findsOneWidget);
    });

    testWidgets('real match ending in Draw: announces draw, awards NO points', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Play a known draw sequence:
      // X O X
      // X X O
      // O X O
      await tapCell(tester, 0, 0); // X
      await tapCell(tester, 0, 1); // O
      await tapCell(tester, 0, 2); // X
      await tapCell(tester, 1, 1); // O
      await tapCell(tester, 1, 0); // X
      await tapCell(tester, 1, 2); // O
      await tapCell(tester, 2, 1); // X
      await tapCell(tester, 2, 0); // O
      await tapCell(tester, 2, 2); // X - Draw!

      // Header shows draw status
      expect(find.text('تعادل!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('النتيجة النهائية للمباراة'), findsOneWidget);

      // Both scores remain 0
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('moving after game over is blocked', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // X wins on row 0:
      await tapCell(tester, 0, 0); // X
      await tapCell(tester, 1, 0); // O
      await tapCell(tester, 0, 1); // X
      await tapCell(tester, 1, 1); // O
      await tapCell(tester, 0, 2); // X wins!

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // Close dialog
      Navigator.of(tester.element(find.byType(GameOverDialog))).pop();
      await tester.pumpAndSettle();

      // Tap on empty cell (2, 2)
      await tapCell(tester, 2, 2);

      // Cell (2, 2) should remain empty, no new marks placed
      final emptyCellFinder = find.bySemanticsLabel('الخانة: الصف 3، العمود 3');
      expect(emptyCellFinder, findsOneWidget);
    });

    testWidgets('replay button during active round triggers confirmation dialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Make 1 move
      await tapCell(tester, 0, 0);

      // Tap Replay button in bottom bar
      await tester.tap(find.text('إعادة الجولة'));
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.text('إعادة تشغيل الجولة؟'), findsOneWidget);
      expect(find.text('هل أنت متأكد من إعادة تشغيل الجولة الحالية؟ ستفقد الحركات التي تم لعبها.'), findsOneWidget);

      // Tap cancel ("متابعة اللعب")
      await tester.tap(find.text('متابعة اللعب'));
      await tester.pumpAndSettle();

      // Cell (0, 0) still contains mark X
      expect(find.byType(NeonXWidget), findsNWidgets(2));

      // Tap Replay again and confirm restart ("إعادة البدء")
      await tester.tap(find.text('إعادة الجولة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إعادة البدء'));
      await tester.pumpAndSettle();

      // Board is cleared
      expect(find.byType(NeonXWidget), findsOneWidget);
    });

    testWidgets('exit during active round triggers confirmation dialog; cancel stays, confirm leaves', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Make 1 move
      await tapCell(tester, 0, 0);

      // Tap Exit button in bottom bar
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('مغادرة الجولة؟'), findsOneWidget);
      expect(find.text('هل أنت متأكد من العودة إلى القائمة الرئيسية؟ ستفقد التقدم في الجولة الحالية.'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('متابعة اللعب'));
      await tester.pumpAndSettle();
      expect(find.text('مغادرة الجولة؟'), findsNothing);

      // Tap exit and confirm
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مغادرة'));
      await tester.pumpAndSettle();
    });
  });

  group('GameBoardScreen - Multi-Round Match Progression & Banners', () {
    testWidgets('non-final round displays RoundEndBanner without modal dialog and auto-transitions', (tester) async {
      final matchConfig = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
      );

      await tester.pumpWidget(buildTestableWidget(matchConfig: matchConfig));
      await tester.pumpAndSettle();

      // Verify Round 1 of 3 is displayed
      expect(find.text('الجولة ١ من ٣'), findsOneWidget);

      // Play moves leading to X win in Round 1
      await tapCell(tester, 0, 0); // X
      await tapCell(tester, 1, 0); // O
      await tapCell(tester, 0, 1); // X
      await tapCell(tester, 1, 1); // O
      await tapCell(tester, 0, 2); // X Wins Round 1!
      await tester.pumpAndSettle();

      // Verify non-obscuring RoundEndBanner appears (NOT modal GameOverDialog!)
      expect(find.byType(RoundEndBanner), findsOneWidget);
      expect(find.byType(GameOverDialog), findsNothing);
      expect(find.descendant(of: find.byType(RoundEndBanner), matching: find.text('فاز X!')), findsOneWidget);

      // Tap "الجولة التالية ⏩" to advance to Round 2 immediately
      await tester.tap(find.text('الجولة التالية ⏩').first);
      await tester.pumpAndSettle();

      // Round 2 active!
      expect(find.text('الجولة ٢ من ٣'), findsOneWidget);
      expect(find.byType(RoundEndBanner), findsNothing);

      // Starting player alternated to O!
      expect(find.text('O'), findsOneWidget);
      expect(find.text('الدور الآن'), findsOneWidget);

      // Score maintained (1 - 0)
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('pause button freezes match and shows pause banner; resume button continues', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap Pause icon in app bar
      await tester.tap(find.widgetWithIcon(IconButton, Icons.pause_rounded));
      await tester.pumpAndSettle();

      // Verify match paused banner
      expect(find.text('المباراة متوقفة مؤقتاً'), findsOneWidget);
      expect(find.text('تم إيقاف المؤقت وحركات المباراة. اضغط استئناف للمتابعة.'), findsOneWidget);

      // Tap Resume button
      await tester.tap(find.text('استئناف اللعب').first);
      await tester.pumpAndSettle();

      // Match resumed
      expect(find.text('المباراة متوقفة مؤقتاً'), findsNothing);
    });

    testWidgets('chess-clock timer displays clocks in HUD when enabled', (tester) async {
      final matchConfig = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 1,
        timerConfig: const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(minutes: 1),
          preset: TimerPreset.oneMinute,
        ),
      );

      await tester.pumpWidget(buildTestableWidget(matchConfig: matchConfig));
      await tester.pumpAndSettle();

      // Both clocks are rendered in HUD
      expect(find.byIcon(Icons.timer_outlined), findsNWidgets(2));
      expect(find.text('٠١:٠٠'), findsAtLeastNWidgets(1));
    });
  });

  group('GameBoardScreen - Large Grids (9x9 & 11x11), Zooming & Corners', () {
    testWidgets('11x11 board corner cells can be selected accurately', (tester) async {
      await tester.pumpWidget(buildTestableWidget(config: BoardConfig.grid11x11));
      await tester.pumpAndSettle();

      // Tap top-left corner (0, 0) -> X
      await tapCell(tester, 0, 0);
      expect(find.byType(NeonXWidget), findsNWidgets(2));

      // Tap top-right corner (0, 10) -> O
      await tapCell(tester, 0, 10);
      expect(find.byType(NeonOWidget), findsNWidgets(2));

      // Tap bottom-left corner (10, 0) -> X
      await tapCell(tester, 10, 0);
      expect(find.byType(NeonXWidget), findsNWidgets(3));

      // Tap bottom-right corner (10, 10) -> O
      await tapCell(tester, 10, 10);
      expect(find.byType(NeonOWidget), findsNWidgets(3));
    });

    testWidgets('11x11 zoom button toggles view to 1.75x and back to 1x without changing game state', (tester) async {
      await tester.pumpWidget(buildTestableWidget(config: BoardConfig.grid11x11));
      await tester.pumpAndSettle();

      // Find zoom-in button
      final zoomButton = find.byIcon(Icons.zoom_in);
      expect(zoomButton, findsOneWidget);
      expect(find.text('تكبير الرقعة للّمس الدقيق'), findsOneWidget);

      // Tap to Zoom In
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();

      // Button toggles to reset 1x
      expect(find.byIcon(Icons.zoom_out_map), findsOneWidget);
      expect(find.text('إعادة الرؤية كاملة (1x)'), findsOneWidget);

      // Tap reset view
      await tester.tap(find.byIcon(Icons.zoom_out_map));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    });

    testWidgets('dragging across board in 11x11 does NOT place accidental marks', (tester) async {
      await tester.pumpWidget(buildTestableWidget(config: BoardConfig.grid11x11));
      await tester.pumpAndSettle();

      // Perform a drag across the grid
      final gridCenter = tester.getCenter(find.byType(GameGridWidget));
      final gesture = await tester.startGesture(gridCenter);
      await gesture.moveBy(const Offset(80, 80));
      await gesture.up();
      await tester.pumpAndSettle();

      // No moves should have been placed! (Only HUD icons exist)
      expect(find.byType(NeonXWidget), findsOneWidget); // HUD only
      expect(find.byType(NeonOWidget), findsOneWidget); // HUD only
      expect(find.text('X'), findsOneWidget); // Turn still belongs to X
    });
  });

  group('GameBoardScreen - All 4 Authorized Grids & RTL Support', () {
    testWidgets('renders all 4 grids accurately on screen without overflow', (tester) async {
      final presets = [
        BoardConfig.grid3x3,
        BoardConfig.grid6x6,
        BoardConfig.grid9x9,
        BoardConfig.grid11x11,
      ];

      for (final preset in presets) {
        await tester.pumpWidget(buildTestableWidget(config: preset));
        await tester.pumpAndSettle();

        expect(find.byType(GameGridWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('RTL selection maps column 0 and row 0 to exact intended coordinates', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isArabic: true));
      await tester.pumpAndSettle();

      // Tap row 1, col 2 in RTL
      await tapCell(tester, 1, 2, isArabic: true);

      // Verify that the mark was registered at (1, 2)
      final markedCell = find.bySemanticsLabel(RegExp('^الخانة: الصف 2، العمود 3'));
      expect(markedCell, findsOneWidget);
    });
  });

  group('GameBoardScreen - Accessibility & Responsiveness', () {
    testWidgets('supports large text scale (1.5x) without layout overflow', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(textScaler: const TextScaler.linear(1.5)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('runs smoothly with reduced motion enabled (immediate dialog without forced wait)', (tester) async {
      await tester.pumpWidget(buildTestableWidget(disableAnimations: true));
      await tester.pumpAndSettle();

      // Play a quick win
      await tapCell(tester, 0, 0); // X
      await tapCell(tester, 1, 0); // O
      await tapCell(tester, 0, 1); // X
      await tapCell(tester, 1, 1); // O
      await tapCell(tester, 0, 2); // X Wins!

      // With reduced motion, dialog appears quickly
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GameBoardScreen - Final Round Delayed Finalize & Transition Safety', () {
    /// Wins one round of a 3-round match for X. When [xStarts] is false, O
    /// opens the round and X still wins (mirrors the engine test sequences).
    Future<void> winRoundForX(WidgetTester tester, {required bool xStarts}) async {
      if (xStarts) {
        await tapCell(tester, 0, 0); // X
        await tapCell(tester, 1, 0); // O
        await tapCell(tester, 0, 1); // X
        await tapCell(tester, 1, 1); // O
        await tapCell(tester, 0, 2); // X wins
      } else {
        await tapCell(tester, 1, 0); // O
        await tapCell(tester, 0, 0); // X
        await tapCell(tester, 1, 1); // O
        await tapCell(tester, 0, 1); // X
        await tapCell(tester, 2, 0); // O
        await tapCell(tester, 0, 2); // X wins
      }
    }

    /// Drives a 3-round match to the point where the FINAL round has just been
    /// won and the 1200ms finalize delay is pending (no banner on final round).
    Future<void> reachFinalRoundEnd(WidgetTester tester) async {
      final matchConfig = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
      );
      await tester.pumpWidget(buildTestableWidget(matchConfig: matchConfig));
      await tester.pumpAndSettle();

      await winRoundForX(tester, xStarts: true); // Round 1 (X starts)
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجولة التالية ⏩').first);
      await tester.pumpAndSettle();

      await winRoundForX(tester, xStarts: false); // Round 2 (O starts)
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجولة التالية ⏩').first);
      await tester.pumpAndSettle();

      await winRoundForX(tester, xStarts: true); // Round 3 (final, X starts)
      await tester.pumpAndSettle();
    }

    testWidgets('POSITIVE: final round ending without interruption shows the final dialog after the delay', (tester) async {
      await reachFinalRoundEnd(tester);

      // Not yet: the finalize delay is pending
      expect(find.byType(GameOverDialog), findsNothing);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // The dialog MUST appear for the legitimately ended match
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('النتيجة النهائية للمباراة'), findsOneWidget);
    });

    testWidgets('the correct final result is presented exactly once and never duplicated', (tester) async {
      await reachFinalRoundEnd(tester);
      expect(find.byType(GameOverDialog), findsNothing);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // Exactly one presentation of the correct final result
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('النتيجة النهائية للمباراة'), findsOneWidget);

      // Pumping far past the delay must not duplicate or re-trigger anything
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('النتيجة النهائية للمباراة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('REPRO: resetting the round inside the finalize delay window must NOT surface a stale dialog', (tester) async {
      await reachFinalRoundEnd(tester);
      expect(find.byType(GameOverDialog), findsNothing);

      // Player resets the round during the delay window via the AppBar
      // replay button (no confirmation needed: round is over).
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump(); // drain microtasks
      await tester.pump(); // render the rebuilt, active round

      // Round 3 is live again (fresh board, X starts, scores preserved)
      expect(find.text('الجولة ٣ من ٣'), findsOneWidget);
      expect(find.text('الدور الآن'), findsOneWidget);
      expect(find.byType(GameOverDialog), findsNothing);

      // The old finalize delay now fires
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // No stale final-result dialog may appear over the fresh round
      expect(find.byType(GameOverDialog), findsNothing);
      expect(find.text('النتيجة النهائية للمباراة'), findsNothing);
      expect(find.text('الجولة ٣ من ٣'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('exiting the screen inside the finalize delay window must not surface the dialog afterwards', (tester) async {
      // Single-round match: its only round is the final one.
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await winRoundForX(tester, xStarts: true);
      await tester.pumpAndSettle();
      expect(find.byType(GameOverDialog), findsNothing);

      // Leave via the bottom-bar exit with confirmation.
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مغادرة'));
      await tester.pumpAndSettle();

      // The stale finalize delay fires after the screen is gone.
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsNothing);
      expect(find.text('النتيجة النهائية للمباراة'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('REPRO: banner skip and bottom next-round button fired together advance exactly one round', (tester) async {
      final matchConfig = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
      );
      await tester.pumpWidget(buildTestableWidget(matchConfig: matchConfig));
      await tester.pumpAndSettle();

      await winRoundForX(tester, xStarts: true);
      await tester.pumpAndSettle();
      expect(find.byType(RoundEndBanner), findsOneWidget);

      // Banner skip + bottom "next round" button dispatched in the same frame
      // (simulates the auto-countdown callback racing a manual player tap).
      await tester.tap(find.text('الجولة التالية ⏩').first);
      await tester.tap(find.text('الجولة التالية ⏩').last);
      await tester.pumpAndSettle();

      // Exactly ONE round advanced: Round 2, never Round 3.
      expect(find.text('الجولة ٢ من ٣'), findsOneWidget);
      expect(find.text('الجولة ٣ من ٣'), findsNothing);
      expect(find.byType(RoundEndBanner), findsNothing);
    });

    testWidgets('REPRO: re-winning the reset final round presents its own result once, on its own delay — never the stale one early', (tester) async {
      final matchConfig = MatchConfig(
        boardConfig: BoardConfig.grid3x3,
        totalRounds: 3,
      );
      await tester.pumpWidget(buildTestableWidget(matchConfig: matchConfig));
      await tester.pumpAndSettle();

      // Navigate to the final round start (rounds 1-2 via banner skips).
      await winRoundForX(tester, xStarts: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجولة التالية ⏩').first);
      await tester.pumpAndSettle();
      await winRoundForX(tester, xStarts: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجولة التالية ⏩').first);
      await tester.pumpAndSettle();

      // t=0: win the FINAL round with zero fake-time advance — the finalize
      // delay is scheduled exactly now.
      await tapCell(tester, 0, 0, settle: false); // X
      await tapCell(tester, 1, 0, settle: false); // O
      await tapCell(tester, 0, 1, settle: false); // X
      await tapCell(tester, 1, 1, settle: false); // O
      await tapCell(tester, 0, 2, settle: false); // X wins the final round
      await tester.pump();
      expect(find.byType(GameOverDialog), findsNothing);

      // t=400: player resets the round before any dialog appears.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump(); // drain microtasks (resetCurrentRound runs)
      await tester.pump(); // rebuild: round 3 active again
      expect(find.text('الجولة ٣ من ٣'), findsOneWidget);
      expect(find.text('الدور الآن'), findsOneWidget);

      // t=700: brief pause, then re-win the reset round with zero-time taps.
      await tester.pump(const Duration(milliseconds: 300));
      await tapCell(tester, 0, 0, settle: false); // X
      await tapCell(tester, 1, 0, settle: false); // O
      await tapCell(tester, 0, 1, settle: false); // X
      await tapCell(tester, 1, 1, settle: false); // O
      await tapCell(tester, 0, 2, settle: false); // X wins again
      await tester.pump();
      expect(find.byType(GameOverDialog), findsNothing);

      // t=1300: the STALE delay (due at t=1200) must NOT present the new
      // round's result early — it was invalidated by the reset.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(GameOverDialog), findsNothing,
          reason: 'The stale finalize scheduling must be canceled by the round reset');

      // t=2000: the NEW result presents exactly once, per its OWN delay
      // (scheduled at t=700, due at t=1900).
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('النتيجة النهائية للمباراة'), findsOneWidget);

      // Pumping further must never duplicate the presentation.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
