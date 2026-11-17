import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import 'package:xo_neon_app/features/game/application/match_providers.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/celebration_banner.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/game_grid_widget.dart';
import 'package:xo_neon_app/features/game/presentation/widgets/game_over_dialog.dart';
import 'package:xo_neon_app/features/online/application/auth_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import '../game/application/fake_system_move_port.dart';

class _MockRoomService extends Fake implements RoomService {
  @override
  Future<RoomModel?> getRoom(String roomCode) async => null;
}

class _MockAuthService extends Fake implements AuthService {
  @override
  String? get currentUid => 'test_uid';
}

void main() {
  const artifactRoot = 'C:/Users/Owner/.gemini/antigravity/brain/112db631-2ccf-4f9f-bb82-5f6c9404bac1';
  const artifactDir = '$artifactRoot/screenshots';
  const projectScreenshotsDir = 'D:/xo_neon_app/screenshots/ux_delight';

  setUpAll(() {
    for (final path in [artifactRoot, artifactDir, projectScreenshotsDir]) {
      final d = Directory(path);
      if (!d.existsSync()) {
        d.createSync(recursive: true);
      }
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
      ProviderScope(
        overrides: [
          systemMovePortProvider.overrideWithValue(const FirstEmptySystemMovePort()),
          authServiceProvider.overrideWithValue(_MockAuthService()),
          roomServiceProvider.overrideWithValue(_MockRoomService()),
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
                child: Scaffold(
                  backgroundColor: const Color(0xFF080611),
                  body: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    if (beforeCapture != null) {
      await beforeCapture(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          File('$projectScreenshotsDir/$filename').writeAsBytesSync(bytes);
          File('$artifactDir/$filename').writeAsBytesSync(bytes);
          File('$artifactRoot/$filename').writeAsBytesSync(bytes);
        }
      }
    });

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('Capture 1: Round Win Moment (Meso)', (tester) async {
    // Board with winning line for X, golden laser line, celebration particles, and banner
    var board = GameBoard.empty(BoardConfig.grid3x3);
    board = board.copyWithMove(const Position(0, 0), Player.x);
    board = board.copyWithMove(const Position(0, 1), Player.x);
    board = board.copyWithMove(const Position(0, 2), Player.x);
    board = board.copyWithMove(const Position(1, 0), Player.o);
    board = board.copyWithMove(const Position(1, 1), Player.o);

    final winningLine = WinningLine(
      positions: const [Position(0, 0), Position(0, 1), Position(0, 2)],
      direction: WinDirection.horizontal,
    );

    await captureWidget(
      tester: tester,
      filename: '01_delight_round_win_meso.png',
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 340,
              height: 340,
              child: GameGridWidget(
                config: BoardConfig.grid3x3,
                board: board,
                currentPlayer: Player.x,
                winningLine: winningLine,
                winner: Player.x,
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: CelebrationBanner(
                type: CelebrationType.roundWon,
              ),
            ),
          ),
        ],
      ),
      beforeCapture: (tester) async {
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });

  testWidgets('Capture 2: Match Win Moment (Macro)', (tester) async {
    // Match win dialog with Crown glyph, sparks, gold auras, score details
    final winningLine = WinningLine(
      positions: const [Position(0, 0), Position(0, 1), Position(0, 2)],
      direction: WinDirection.horizontal,
    );

    await captureWidget(
      tester: tester,
      filename: '02_delight_match_win_macro.png',
      child: GameOverDialog(
        status: GameWon(winner: Player.x, winningLine: winningLine),
        isFinalMatchResult: true,
        matchWinner: Player.x,
        isHumanWinner: true,
        scoreX: 3,
        scoreO: 1,
        moveCount: 14,
        winRatePercentage: 75,
        streakWins: 3,
        onRematch: () {},
        onExit: () {},
      ),
      beforeCapture: (tester) async {
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('Capture 3: Match Draw Moment (Calm Interlocking X/O)', (tester) async {
    // Match draw dialog with interlocking X/O glyph, calm cyan, no gold, no particles
    await captureWidget(
      tester: tester,
      filename: '03_delight_match_draw_calm.png',
      child: GameOverDialog(
        status: const GameDraw(),
        isFinalMatchResult: true,
        matchWinner: null,
        isHumanWinner: null,
        scoreX: 2,
        scoreO: 2,
        moveCount: 24,
        onRematch: () {},
        onExit: () {},
      ),
      beforeCapture: (tester) async {
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });
}
