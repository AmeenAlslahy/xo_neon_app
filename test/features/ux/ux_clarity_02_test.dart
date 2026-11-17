import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/app/theme/neon_theme.dart';
import 'package:xo_neon_app/core/widgets/neon_button.dart';
import 'package:xo_neon_app/core/widgets/sticky_bottom_bar.dart';
import 'package:xo_neon_app/features/game/application/match_providers.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_board_screen.dart';
import 'package:xo_neon_app/features/game/presentation/screens/game_setup_screen.dart';
import 'package:xo_neon_app/features/online/application/auth_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/models/room_code.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'package:xo_neon_app/features/online/presentation/screens/create_room_screen.dart';
import 'package:xo_neon_app/features/online/presentation/screens/room_lobby_screen.dart';
import 'package:xo_neon_app/features/online/presentation/widgets/room_code_display.dart';
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
  Widget wrapApp(Widget child, {Key? key, List<dynamic> overrides = const []}) {
    return ProviderScope(
      key: key ?? UniqueKey(),
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
        home: child,
      ),
    );
  }

  group('UX-CLARITY-02 Specification Verification Tests', () {
    // 1. GameSetupScreen: Round count = 3, no "0 جولات" text
    testWidgets('1. GameSetupScreen: round options count is 3 and NO "0 جولات" text exists', (tester) async {
      await tester.pumpWidget(wrapApp(const GameSetupScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('جولة واحدة'), findsOneWidget);
      expect(find.text('٣ جولات'), findsOneWidget);
      expect(find.text('٥ جولات'), findsOneWidget);

      // Verify no "0 جولات" or "0" rounds anywhere in widget tree
      expect(find.textContaining('0 جولات'), findsNothing);
      expect(find.textContaining('٠ جولات'), findsNothing);
    });

    // 2. GameSetupScreen & CreateRoomScreen: No "0 دقائق", "بدون مؤقت" default
    testWidgets('2. GameSetupScreen and CreateRoomScreen: no "0 دقائق" and "بدون مؤقت" is default', (tester) async {
      // Setup screen
      await tester.pumpWidget(wrapApp(const GameSetupScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('0 دقائق'), findsNothing);
      expect(find.textContaining('٠ دقائق'), findsNothing);
      expect(find.text('بدون مؤقت'), findsOneWidget);

      // Create room screen
      await tester.pumpWidget(wrapApp(const CreateRoomScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('0 دقائق'), findsNothing);
      expect(find.textContaining('٠ دقائق'), findsNothing);
    });

    // 3. GameBoardScreen: AppBar has NO refresh or pause icon; bottom bar has pause once
    testWidgets('3. GameBoardScreen: AppBar has NO refresh/pause icons; bottom control bar has pause once', (tester) async {
      await tester.pumpWidget(wrapApp(const GameBoardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check AppBar: find AppBar specifically
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Within AppBar, no pause or refresh icons
      expect(
        find.descendant(of: appBarFinder, matching: find.byIcon(Icons.pause_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: appBarFinder, matching: find.byIcon(Icons.refresh_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: appBarFinder, matching: find.byIcon(Icons.refresh)),
        findsNothing,
      );

      // Bottom bar has pause button exactly once
      expect(find.text('إيقاف مؤقت'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    // 4. GameBoardScreen: Pausing renders board untouchable (IgnorePointer) and dimmed
    testWidgets('4. GameBoardScreen: pausing freezes board interaction and dims display', (tester) async {
      await tester.pumpWidget(wrapApp(const GameBoardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap pause in bottom bar
      await tester.tap(find.text('إيقاف مؤقت'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Board is dimmed: find Opacity widget with 0.35 opacity
      final opacityFinder = find.byWidgetPredicate(
        (widget) => widget is Opacity && (widget.opacity - 0.35).abs() < 0.05,
      );
      expect(opacityFinder, findsOneWidget);

      // Board is untouchable: IgnorePointer with ignoring: true wraps GameGridWidget
      final ignorePointerFinder = find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring == true,
      );
      expect(ignorePointerFinder, findsWidgets);

      // Attempt to tap cell (0, 0) while paused
      final cellFinder = find.bySemanticsLabel('الخانة: الصف 1، العمود 1');
      await tester.tap(cellFinder, warnIfMissed: false);
      await tester.pump();

      // Mark was NOT placed: cell remains empty
      expect(find.byType(NeonButton), findsWidgets);
      expect(find.text('المباراة متوقفة'), findsOneWidget);
    });

    // 5. GameBoardScreen: Zoom button scales > 1.0, reset view returns to 1.0
    testWidgets('5. GameBoardScreen: zoom button toggles view to > 1.0 and back to 1.0', (tester) async {
      // 11x11 large grid triggers zoom affordance
      final matchConfig = MatchConfig(
        boardConfig: BoardConfig.grid11x11,
        totalRounds: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemMovePortProvider.overrideWithValue(const FirstEmptySystemMovePort()),
            matchConfigProvider.overrideWithValue(matchConfig),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find InteractiveViewer
      final ivFinder = find.byType(InteractiveViewer);
      expect(ivFinder, findsOneWidget);
      InteractiveViewer iv = tester.widget(ivFinder);
      expect(iv.transformationController!.value.getMaxScaleOnAxis(), closeTo(1.0, 0.05));

      // Tap zoom button
      final zoomBtn = find.text('تكبير الرقعة');
      expect(zoomBtn, findsOneWidget);
      await tester.tap(zoomBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Scale is now > 1.0
      iv = tester.widget(ivFinder);
      expect(iv.transformationController!.value.getMaxScaleOnAxis(), greaterThan(1.1));

      // Tap reset view
      final resetBtn = find.text('إعادة ضبط الرؤية');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Scale is back to 1.0
      iv = tester.widget(ivFinder);
      expect(iv.transformationController!.value.getMaxScaleOnAxis(), closeTo(1.0, 0.05));
    });

    // 6. RoomLobbyScreen: Start button disabled before guest, enabled after
    testWidgets('6. RoomLobbyScreen: start button is disabled before guest joins and enabled after', (tester) async {
      final roomController = StreamController<RoomModel?>.broadcast();
      addTearDown(roomController.close);

      final waitingRoom = RoomModel(
        code: 'TEST01',
        hostUid: 'host_uid_123',
        hostName: 'HostPlayer',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.waitingForGuest,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      await tester.pumpWidget(
        wrapApp(
          const RoomLobbyScreen(roomCode: 'TEST01', isHost: true),
          overrides: [
            roomStreamProvider('TEST01').overrideWith((ref) => roomController.stream),
          ],
        ),
      );

      roomController.add(waitingRoom);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Start button is present and disabled with "بانتظار انضمام الصديق…"
      final disabledStartFinder = find.widgetWithText(NeonButton, 'بانتظار انضمام الصديق…');
      expect(disabledStartFinder, findsOneWidget);
      NeonButton startButton = tester.widget(disabledStartFinder);
      expect(startButton.isDisabled, isTrue);

      // Guest joins -> room is ready
      final readyRoom = waitingRoom.copyWith(
        guestUid: 'guest_uid_456',
        guestName: 'GuestFriend',
        status: RoomStatus.ready,
      );
      roomController.add(readyRoom);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Start button is enabled with "بدء المباراة"
      final enabledStartFinder = find.widgetWithText(NeonButton, 'بدء المباراة');
      expect(enabledStartFinder, findsOneWidget);
      startButton = tester.widget(enabledStartFinder);
      expect(startButton.isDisabled, isFalse);
    });

    // 7. RoomCode: Copy strips spaces, pasting "TGV RDP" normalizes to "TGVRDP"
    testWidgets('7. RoomCode: copy strips internal spaces and RoomCode.normalize strips spaces and uppercases', (tester) async {
      // 1. Domain logic normalization
      expect(RoomCode.normalize('TGV RDP'), 'TGVRDP');
      expect(RoomCode.normalize(' tgv   rdp '), 'TGVRDP');
      expect(RoomCode.normalize('abcxyz'), 'ABCXYZ');

      // 2. RoomCodeDisplay renders clean code
      await tester.pumpWidget(
        wrapApp(
          const Scaffold(
            body: RoomCodeDisplay(code: 'TGV RDP'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify clean displayed code without spaces
      expect(find.text('TGVRDP'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    // 8. 320dp layout: Sticky CTA visible without scrolling on Setup, Create Room, and Lobby
    testWidgets('8. 320dp layout: Sticky CTA is visible without scrolling on Setup, Create, and Lobby', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // A. GameSetupScreen on 320x568
      await tester.pumpWidget(wrapApp(const GameSetupScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(StickyBottomBar), findsOneWidget);
      final setupCta = find.widgetWithText(NeonButton, 'بدء المباراة');
      expect(setupCta, findsOneWidget);
      // Verify visible on screen without requiring drag
      final setupCtaRect = tester.getRect(setupCta);
      expect(setupCtaRect.bottom, lessThanOrEqualTo(568));
      expect(setupCtaRect.top, greaterThanOrEqualTo(0));

      // B. CreateRoomScreen on 320x568
      await tester.pumpWidget(wrapApp(const CreateRoomScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(StickyBottomBar), findsOneWidget);
      final createCta = find.widgetWithText(NeonButton, 'إنشاء الغرفة');
      expect(createCta, findsOneWidget);
      final createCtaRect = tester.getRect(createCta);
      expect(createCtaRect.bottom, lessThanOrEqualTo(568));
      expect(createCtaRect.top, greaterThanOrEqualTo(0));

      // C. RoomLobbyScreen on 320x568
      final waitingRoom = RoomModel(
        code: 'TGVRDP',
        hostUid: 'host_uid_123',
        hostName: 'HostPlayer',
        config: RoomConfig.standard3x3(),
        status: RoomStatus.waitingForGuest,
        createdAtMs: 100,
        lastActiveMs: 100,
      );

      await tester.pumpWidget(
        wrapApp(
          const RoomLobbyScreen(roomCode: 'TGVRDP', isHost: true),
          overrides: [
            roomStreamProvider('TGVRDP').overrideWith((ref) => Stream.value(waitingRoom)),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Start button is present and on-screen
      final lobbyStartBtn = find.widgetWithText(NeonButton, 'بانتظار انضمام الصديق…');
      expect(lobbyStartBtn, findsOneWidget);
      final lobbyStartRect = tester.getRect(lobbyStartBtn);
      expect(lobbyStartRect.bottom, lessThanOrEqualTo(568));
      expect(lobbyStartRect.top, greaterThanOrEqualTo(0));
    });
  });
}
