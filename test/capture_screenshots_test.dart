import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_colors.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import 'package:xo_neon_app/core/l10n/app_strings.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_setup_screen.dart';
import 'package:xo_neon_app/features/game/presentation/screens/home_screen.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/game_grid_widget.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/game_over_dialog.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/player_turn_header.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/round_end_banner.dart';

void main() {
  setUpAll(() {
    final dir = Directory('D:/xo_neon_app/screenshots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  });

  Future<void> captureWidget({
    required WidgetTester tester,
    required Widget child,
    required String filename,
    Size surfaceSize = const Size(390, 844),
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final repaintKey = GlobalKey();

    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: NeonTheme.darkTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RepaintBoundary(
          key: repaintKey,
          child: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
              devicePixelRatio: 1.0,
            ),
            child: SizedBox(
              width: surfaceSize.width,
              height: surfaceSize.height,
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (beforeCapture != null) {
      await beforeCapture(tester);
      await tester.pumpAndSettle();
    }

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File('D:/xo_neon_app/screenshots/$filename');
          file.writeAsBytesSync(byteData.buffer.asUint8List());
        }
      }
    });

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('Capture Screen 1: HomeScreen', (tester) async {
    await captureWidget(
      tester: tester,
      child: const HomeScreen(isArabic: true),
      filename: '01_home_screen.png',
    );
  });

  testWidgets('Capture Screen 2: GameSetupScreen with Rounds & Chess Clock Timer', (tester) async {
    await captureWidget(
      tester: tester,
      child: const GameSetupScreen(isArabic: true),
      filename: '02_setup_screen.png',
    );
  });

  testWidgets('Capture Screen 3: 3x3 Game Board Active Play', (tester) async {
    final config = BoardConfig.grid3x3;
    var board = GameBoard.empty(config);
    board = board.copyWithMove(const Position(0, 0), Player.x);
    board = board.copyWithMove(const Position(1, 1), Player.o);
    board = board.copyWithMove(const Position(2, 0), Player.x);

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('٣×٣ (كلاسيكي)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.o,
                    config: config,
                    scoreX: 1,
                    scoreO: 0,
                    currentRound: 1,
                    totalRounds: 3,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        currentPlayer: Player.o,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '03_board_3x3_screen.png',
    );
  });

  testWidgets('Capture Screen 4: 6x6 Tactical Game Board Active Play', (tester) async {
    final config = BoardConfig.grid6x6;
    var board = GameBoard.empty(config);
    board = board.copyWithMove(const Position(1, 1), Player.x);
    board = board.copyWithMove(const Position(1, 2), Player.o);
    board = board.copyWithMove(const Position(2, 2), Player.x);
    board = board.copyWithMove(const Position(2, 3), Player.o);
    board = board.copyWithMove(const Position(3, 3), Player.x);

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('٦×٦ (تكتيكي)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.o,
                    config: config,
                    scoreX: 0,
                    scoreO: 0,
                    currentRound: 1,
                    totalRounds: 3,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        currentPlayer: Player.o,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '04_board_6x6_screen.png',
    );
  });

  testWidgets('Capture Screen 5: 9x9 Pro Game Board Active Play', (tester) async {
    final config = BoardConfig.grid9x9;
    var board = GameBoard.empty(config);
    board = board.copyWithMove(const Position(4, 4), Player.x);
    board = board.copyWithMove(const Position(4, 5), Player.o);
    board = board.copyWithMove(const Position(3, 4), Player.x);
    board = board.copyWithMove(const Position(5, 4), Player.o);
    board = board.copyWithMove(const Position(2, 4), Player.x);

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('٩×٩ (احترافي)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.o,
                    config: config,
                    scoreX: 2,
                    scoreO: 1,
                    currentRound: 2,
                    totalRounds: 3,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        currentPlayer: Player.o,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '05_board_9x9_screen.png',
    );
  });

  testWidgets('Capture Screen 6: 11x11 Master Game Board (Full Tactical Overview)', (tester) async {
    final config = BoardConfig.grid11x11;
    var board = GameBoard.empty(config);
    board = board.copyWithMove(const Position(5, 5), Player.x);
    board = board.copyWithMove(const Position(5, 6), Player.o);
    board = board.copyWithMove(const Position(6, 5), Player.x);
    board = board.copyWithMove(const Position(4, 5), Player.o);
    board = board.copyWithMove(const Position(7, 5), Player.x);

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('١١×١١ (أسطوري - رؤية كاملة)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.o,
                    config: config,
                    scoreX: 1,
                    scoreO: 1,
                    currentRound: 3,
                    totalRounds: 3,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        currentPlayer: Player.o,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '06_board_11x11_screen.png',
    );
  });

  testWidgets('Capture Screen 6b: 11x11 Master Game Board Zoomed In (1.75x)', (tester) async {
    final config = BoardConfig.grid11x11;
    var board = GameBoard.empty(config);
    board = board.copyWithMove(const Position(5, 5), Player.x);
    board = board.copyWithMove(const Position(5, 6), Player.o);
    board = board.copyWithMove(const Position(6, 5), Player.x);
    board = board.copyWithMove(const Position(4, 5), Player.o);
    board = board.copyWithMove(const Position(7, 5), Player.x);

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('١١×١١ (أسطوري - وضع التكبير)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.o,
                    config: config,
                    scoreX: 1,
                    scoreO: 1,
                    currentRound: 3,
                    totalRounds: 3,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        currentPlayer: Player.o,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '06_board_11x11_zoomed.png',
      beforeCapture: (tester) async {
        final zoomButton = find.byIcon(Icons.zoom_in);
        expect(zoomButton, findsOneWidget);
        await tester.tap(zoomButton);
      },
    );
  });

  testWidgets('Capture Screen 7: Active Match with Chess Clocks & Low Time Warning', (tester) async {
    final config = BoardConfig.grid3x3;
    var board = GameBoard.empty(config);
    board = board.copyWithMove(const Position(0, 0), Player.x);
    board = board.copyWithMove(const Position(1, 1), Player.o);
    board = board.copyWithMove(const Position(2, 0), Player.x);

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('٣×٣ (كلاسيكي)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.o,
                    config: config,
                    scoreX: 1,
                    scoreO: 0,
                    currentRound: 2,
                    totalRounds: 3,
                    isTimerEnabled: true,
                    remainingTimeX: const Duration(seconds: 42),
                    remainingTimeO: const Duration(seconds: 8), // Low time warning!
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        currentPlayer: Player.o,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '07_active_match_rounds_and_timers.png',
    );
  });

  testWidgets('Capture Screen 8: Round Victory with Laser Line and Non-Obscuring Banner', (tester) async {
    final config = BoardConfig.grid3x3;
    var board = GameBoard.empty(config);
    // Diagonal win for Player X
    board = board.copyWithMove(const Position(0, 0), Player.x);
    board = board.copyWithMove(const Position(0, 1), Player.o);
    board = board.copyWithMove(const Position(1, 1), Player.x);
    board = board.copyWithMove(const Position(0, 2), Player.o);
    board = board.copyWithMove(const Position(2, 2), Player.x);

    final winningLine = WinningLine(
      positions: const [Position(0, 0), Position(1, 1), Position(2, 2)],
      direction: WinDirection.diagonal,
    );

    final matchState = MatchState(
      config: MatchConfig(boardConfig: config, totalRounds: 3),
      currentRound: 1,
      scoreX: 1,
      scoreO: 0,
      roundStartingPlayer: Player.x,
      roundState: GameState.initial(config: config).copyWith(
        board: board,
        status: GameWon(winner: Player.x, winningLine: winningLine),
      ),
      phase: MatchPhase.roundEnded,
      roundEndReason: RoundEndReason.win,
      roundWinner: Player.x,
      remainingTimeX: const Duration(seconds: 52),
      remainingTimeO: const Duration(seconds: 58),
    );

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('٣×٣ (كلاسيكي)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.x,
                    config: config,
                    scoreX: 1,
                    scoreO: 0,
                    currentRound: 1,
                    totalRounds: 3,
                    status: GameWon(
                      winner: Player.x,
                      winningLine: winningLine,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        winningLine: winningLine,
                        winner: Player.x,
                        currentPlayer: Player.x,
                      ),
                    ),
                  ),
                  RoundEndBanner(
                    matchState: matchState,
                    onNextRound: () {},
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '08_round_victory_winning_line_and_banner.png',
    );
  });

  testWidgets('Capture Screen 9: Final Match Result Dialog (Overall Winner)', (tester) async {
    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.65),
        body: Center(
          child: GameOverDialog(
            status: GameWon(
              winner: Player.x,
              winningLine: WinningLine(
                positions: const [Position(0, 0), Position(1, 1), Position(2, 2)],
                direction: WinDirection.diagonal,
              ),
            ),
            isFinalMatchResult: true,
            scoreX: 2,
            scoreO: 1,
            matchWinner: Player.x,
            strings: const AppStrings(isArabic: true),
            onRematch: () {},
            onViewBoard: () {},
            onExit: () {},
          ),
        ),
      ),
      filename: '09_final_match_result_dialog.png',
    );
  });

  testWidgets('Capture Screen 10: Paused Match Screen', (tester) async {
    final config = BoardConfig.grid3x3;
    var board = GameBoard.empty(config);
    board = board.copyWithMove(const Position(1, 1), Player.x);

    await captureWidget(
      tester: tester,
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          title: const Text('٣×٣ (كلاسيكي)'),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  PlayerTurnHeader(
                    currentPlayer: Player.o,
                    config: config,
                    scoreX: 1,
                    scoreO: 1,
                    currentRound: 2,
                    totalRounds: 3,
                    isPaused: true,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF160E36),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NeonColors.amberGold, width: 1.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.pause_circle_filled_rounded, color: NeonColors.amberGold, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم إيقاف المؤقت وحركات المباراة. اضغط استئناف للمتابعة.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: GameGridWidget(
                        config: config,
                        board: board,
                        currentPlayer: Player.o,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      filename: '10_paused_match_screen.png',
    );
  });
}
