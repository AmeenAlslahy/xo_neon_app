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
import 'package:xo_neon_app/features/game/presentation/screens/game_board_screen.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_setup_screen.dart';
import 'package:xo_neon_app/features/online/application/auth_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'package:xo_neon_app/features/online/presentation/screens/create_room_screen.dart';
import 'package:xo_neon_app/features/online/presentation/screens/online_lobby_entry_screen.dart';
import 'package:xo_neon_app/features/online/presentation/screens/room_lobby_screen.dart';
import '../game/application/fake_system_move_port.dart';

class _MockRoomService extends Fake implements RoomService {
  @override
  Future<RoomModel?> getRoom(String roomCode) async => null;
  @override
  Future<void> registerHostLobbyDisconnect({required String roomCode, required String hostUid}) async {}
  @override
  Future<void> cancelDisconnectHandlers(String roomCode) async {}
}

class _MockAuthService extends Fake implements AuthService {
  @override
  String? get currentUid => 'host_uid_123';
}

void main() {
  const artifactDir = 'C:/Users/Owner/.gemini/antigravity/brain/112db631-2ccf-4f9f-bb82-5f6c9404bac1/screenshots';
  const projectScreenshotsDir = 'D:/xo_neon_app/screenshots/ux_clarity';

  setUpAll(() {
    for (final path in [artifactDir, projectScreenshotsDir]) {
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
    List<dynamic> overrides = const [],
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
          ...overrides.cast(),
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
                child: child,
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
        }
      }
    });

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final sampleLobbyRoom = RoomModel(
    code: 'TGVRDP',
    hostUid: 'host_uid_123',
    hostName: 'CyberPlayer',
    config: RoomConfig.standard3x3(),
    status: RoomStatus.waitingForGuest,
    createdAtMs: 100,
    lastActiveMs: 100,
  );

  group('UX-CLARITY-02 Screenshot Capture Suite', () {
    // 1. Five screens at 390x844
    testWidgets('1. Match Setup (390x844)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const GameSetupScreen(),
        filename: '01_setup_390x844.png',
        surfaceSize: const Size(390, 844),
      );
    });

    testWidgets('2. Game Board (390x844)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const GameBoardScreen(),
        filename: '02_board_390x844.png',
        surfaceSize: const Size(390, 844),
      );
    });

    testWidgets('3. Online Entry (390x844)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const OnlineLobbyEntryScreen(),
        filename: '03_online_entry_390x844.png',
        surfaceSize: const Size(390, 844),
      );
    });

    testWidgets('4. Create Room (390x844)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const CreateRoomScreen(),
        filename: '04_create_room_390x844.png',
        surfaceSize: const Size(390, 844),
      );
    });

    testWidgets('5. Room Lobby (390x844)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const RoomLobbyScreen(roomCode: 'TGVRDP', isHost: true),
        overrides: [
          roomStreamProvider('TGVRDP').overrideWith((ref) => Stream.value(sampleLobbyRoom)),
        ],
        filename: '05_room_lobby_390x844.png',
        surfaceSize: const Size(390, 844),
      );
    });

    // 2. Three narrow screens at 320x568
    testWidgets('6. Match Setup (320x568 narrow)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const GameSetupScreen(),
        filename: '06_setup_320x568.png',
        surfaceSize: const Size(320, 568),
      );
    });

    testWidgets('7. Create Room (320x568 narrow)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const CreateRoomScreen(),
        filename: '07_create_room_320x568.png',
        surfaceSize: const Size(320, 568),
      );
    });

    testWidgets('8. Room Lobby (320x568 narrow)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const RoomLobbyScreen(roomCode: 'TGVRDP', isHost: true),
        overrides: [
          roomStreamProvider('TGVRDP').overrideWith((ref) => Stream.value(sampleLobbyRoom)),
        ],
        filename: '08_room_lobby_320x568.png',
        surfaceSize: const Size(320, 568),
      );
    });

    // 3. Game Board at 430x932
    testWidgets('9. Game Board (430x932 large phone)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const GameBoardScreen(),
        filename: '09_board_430x932.png',
        surfaceSize: const Size(430, 932),
      );
    });

    // 4. Game Board at 844x390 landscape
    testWidgets('10. Game Board (844x390 landscape)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const GameBoardScreen(),
        filename: '10_board_844x390_landscape.png',
        surfaceSize: const Size(844, 390),
      );
    });

    // 5. Tablet 800x1280
    testWidgets('11. Match Setup (800x1280 tablet)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const GameSetupScreen(),
        filename: '11_setup_800x1280_tablet.png',
        surfaceSize: const Size(800, 1280),
      );
    });

    testWidgets('12. Game Board (800x1280 tablet)', (tester) async {
      await captureWidget(
        tester: tester,
        child: const GameBoardScreen(),
        filename: '12_board_800x1280_tablet.png',
        surfaceSize: const Size(800, 1280),
      );
    });

    // 6. 9x9 Board zoomed view
    testWidgets('13. 9x9 Game Board (Zoomed view)', (tester) async {
      final config9x9 = MatchConfig(
        boardConfig: BoardConfig.grid9x9,
        totalRounds: 1,
      );

      await captureWidget(
        tester: tester,
        overrides: [
          matchConfigProvider.overrideWithValue(config9x9),
        ],
        beforeCapture: (t) async {
          final zoomBtn = find.text('تكبير الرقعة');
          if (zoomBtn.evaluate().isNotEmpty) {
            await t.tap(zoomBtn);
            await t.pump();
            await t.pump(const Duration(milliseconds: 300));
          }
        },
        child: const GameBoardScreen(),
        filename: '13_board_9x9_zoomed.png',
        surfaceSize: const Size(390, 844),
      );
    });
  });
}
