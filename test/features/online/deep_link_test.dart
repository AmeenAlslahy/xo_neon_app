import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xo_neon_app/core/l10n/app_strings.dart';
import 'package:xo_neon_app/core/l10n/locale_providers.dart';
import 'package:xo_neon_app/core/widgets/neon_button.dart';
import 'package:xo_neon_app/features/online/application/active_session_tracker.dart';
import 'package:xo_neon_app/features/online/application/deep_link_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/application/share_service.dart';
import 'package:xo_neon_app/features/online/presentation/screens/join_room_screen.dart';
import 'package:xo_neon_app/main.dart';

class FakeRoomService extends RoomService {
  FakeRoomService({this.leaveResult = const LeaveRoomSuccess()});

  LeaveRoomResult leaveResult;
  int leaveCallCount = 0;
  String? lastLeftRoomCode;
  bool? lastIsMatch;

  @override
  Future<LeaveRoomResult> leaveRoom({
    required String roomCode,
    required String uid,
    bool? isHost,
    bool isMatch = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    leaveCallCount++;
    lastLeftRoomCode = roomCode;
    lastIsMatch = isMatch;
    return leaveResult;
  }
}

class FakeDeepLinkService extends DeepLinkService {
  FakeDeepLinkService({this.initialCode, Stream<String>? stream})
    : _stream = stream ?? const Stream.empty();

  final String? initialCode;
  final Stream<String> _stream;

  @override
  Future<String?> getInitialCode() async => initialCode;

  @override
  Stream<String> codeStream() => _stream;
}

void main() {
  group('Deep Link Unit & Parsing Tests', () {
    test('Invite link is a clickable HTTPS URL with room code only', () {
      const code = 'A7K9X2';
      final link = DeepLinkService.createInviteLink(code);

      expect(link, 'https://xo-neon-online.web.app/join?code=A7K9X2');
      expect(link.startsWith('https://'), isTrue);
      expect(link.contains('xoneon://'), isFalse);
      expect(link.contains('uid'), isFalse);
      expect(link.contains('token'), isFalse);
      expect(link.contains('secret'), isFalse);
    });

    test('Invite link carries the requested page language', () {
      expect(
        DeepLinkService.createInviteLink('A7K9X2', languageCode: 'ar'),
        'https://xo-neon-online.web.app/join?code=A7K9X2&lang=ar',
      );
      expect(
        DeepLinkService.createInviteLink('A7K9X2', languageCode: 'en'),
        'https://xo-neon-online.web.app/join?code=A7K9X2&lang=en',
      );
      expect(
        DeepLinkService.createInviteLink('A7K9X2', languageCode: 'fr'),
        'https://xo-neon-online.web.app/join?code=A7K9X2',
      );
    });

    test('App link keeps the custom scheme for the web fallback button', () {
      expect(
        DeepLinkService.createAppLink('A7K9X2'),
        'xoneon://join?code=A7K9X2',
      );
    });

    test(
      'parseRoomCode extracts code from HTTPS query parameter and normalizes',
      () {
        final uri = Uri.parse(
          'https://xo-neon-online.web.app/join?code=k3m9p4&lang=ar',
        );
        final code = DeepLinkService.parseRoomCode(uri);

        expect(code, 'K3M9P4');
      },
    );

    test('parseRoomCode extracts code from query parameter and normalizes', () {
      final uri = Uri.parse('xoneon://join?code=k3m9p4');
      final code = DeepLinkService.parseRoomCode(uri);

      expect(code, 'K3M9P4');
    });

    test('parseRoomCode extracts code from path segment', () {
      final uri = Uri.parse('xoneon://join/B8W2R5');
      final code = DeepLinkService.parseRoomCode(uri);

      expect(code, 'B8W2R5');
    });

    test('parseRoomCode extracts code from HTTPS path segment', () {
      final uri = Uri.parse('https://xo-neon-online.web.app/join/B8W2R5');
      final code = DeepLinkService.parseRoomCode(uri);

      expect(code, 'B8W2R5');
    });

    test('parseRoomCode returns null for invalid codes', () {
      expect(
        DeepLinkService.parseRoomCode(Uri.parse('xoneon://join?code=12')),
        isNull,
      );
      expect(
        DeepLinkService.parseRoomCode(
          Uri.parse('xoneon://join?code=TOO_LONG_123'),
        ),
        isNull,
      );
      expect(
        DeepLinkService.parseRoomCode(Uri.parse('xoneon://join?code=')),
        isNull,
      );
    });

    test('createShareMessage includes HTTPS link, language, and manual fallback in Arabic', () {
      final msg = DeepLinkService.createShareMessage(
        roomCode: 'X9Y2Z4',
        isArabic: true,
      );

      expect(
        msg,
        contains('https://xo-neon-online.web.app/join?code=X9Y2Z4&lang=ar'),
      );
      expect(msg, contains('رمز الغرفة: X9Y2Z4'));
      expect(msg, contains('أدخل رمز الغرفة يدويًا'));
    });

    test('createShareMessage includes HTTPS link, language, and manual fallback in English', () {
      final msg = DeepLinkService.createShareMessage(
        roomCode: 'X9Y2Z4',
        isArabic: false,
      );

      expect(
        msg,
        contains('https://xo-neon-online.web.app/join?code=X9Y2Z4&lang=en'),
      );
      expect(msg, contains('Room Code: X9Y2Z4'));
      expect(msg, contains('enter the room code manually'));
    });

    test(
      'ShareService calls share callback with correct message without secrets',
      () async {
        String? sharedText;
        String? sharedSubject;

        final service = ShareService(
          shareFn: (text, {subject, sharePositionOrigin}) async {
            sharedText = text;
            sharedSubject = subject;
            return const ShareResult('ok', ShareResultStatus.success);
          },
        );

        await service.shareRoomInvite(roomCode: 'K2M4P6', isArabic: true);

        expect(sharedText, contains('K2M4P6'));
        expect(
          sharedText,
          contains('https://xo-neon-online.web.app/join?code=K2M4P6&lang=ar'),
        );
        expect(sharedText, isNot(contains('xoneon://')));
        expect(sharedSubject, 'دعوة لمباراة XO نيون');
      },
    );
  });

  group('Deep Link Widget & Navigation Tests', () {
    testWidgets('JoinRoomScreen prefills initialCode but DOES NOT auto-join', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: JoinRoomScreen(initialCode: 'C4D7E9')),
        ),
      );

      await tester.pumpAndSettle();

      // Verify code is prefilled in the text field
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, 'C4D7E9');

      // Verify user is NOT auto-joined (Join button is present and waiting for confirmation)
      final strings = const AppStrings(isArabic: true);
      expect(find.text(strings.joinButton), findsOneWidget);
    });

    testWidgets(
      'Cold start deep link routes to JoinRoomScreen with prefilled code',
      (tester) async {
        final fakeService = FakeDeepLinkService(initialCode: 'H7J2K9');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [deepLinkServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const DeepLinkCoordinator(
                child: Scaffold(body: Text('Home Content')),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // DeepLinkCoordinator navigated to JoinRoomScreen
        expect(find.byType(JoinRoomScreen), findsOneWidget);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'H7J2K9');
      },
    );

    testWidgets('Runtime incoming link routes to JoinRoomScreen when idle', (
      tester,
    ) async {
      final controller = StreamController<String>.broadcast();
      final fakeService = FakeDeepLinkService(stream: controller.stream);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [deepLinkServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const DeepLinkCoordinator(
              child: Scaffold(body: Text('Home Idle')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Home Idle'), findsOneWidget);

      // Fire deep link event
      controller.add('W5X8Y2');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(JoinRoomScreen), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'W5X8Y2');

      await controller.close();
    });

    testWidgets(
      'Active session protection: link does NOT silently replace active match',
      (tester) async {
        final controller = StreamController<String>.broadcast();
        final fakeService = FakeDeepLinkService(stream: controller.stream);

        final container = ProviderContainer(
          overrides: [deepLinkServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        // Simulate active session
        container
            .read(activeSessionProvider.notifier)
            .setActiveSession(
              const ActiveSession(
                roomCode: 'ACTIVE1',
                isHost: true,
                isInGame: true,
              ),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const DeepLinkCoordinator(
                child: Scaffold(body: Text('Active Match Running')),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Incoming link arrives during active session
        controller.add('NEW999');
        await tester.pump();
        await tester.pumpAndSettle();

        // Must show alert dialog asking user whether to leave instead of silent replace
        final strings = container.read(stringsProvider);
        expect(find.text(strings.activeSessionInviteTitle), findsOneWidget);
        expect(
          find.text(strings.activeSessionInviteMessage('NEW999')),
          findsOneWidget,
        );

        // If user chooses stay: stays in current session
        await tester.tap(find.text(strings.stayInCurrentSession));
        await tester.pumpAndSettle();

        expect(find.text('Active Match Running'), findsOneWidget);
        expect(find.byType(JoinRoomScreen), findsNothing);

        await controller.close();
      },
    );

    testWidgets(
      'Active session: confirming leave calls leaveRoom, pops to root, and opens JoinRoomScreen on success',
      (tester) async {
        final controller = StreamController<String>.broadcast();
        final fakeService = FakeDeepLinkService(stream: controller.stream);
        final fakeRoomService = FakeRoomService(
          leaveResult: const LeaveRoomSuccess(),
        );

        final container = ProviderContainer(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
            roomServiceProvider.overrideWithValue(fakeRoomService),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(activeSessionProvider.notifier)
            .setActiveSession(
              const ActiveSession(
                roomCode: 'ACTIVE2',
                isHost: true,
                isInGame: true,
              ),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const DeepLinkCoordinator(
                child: Scaffold(body: Text('Active Match Running')),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Incoming link arrives
        controller.add('SUCC88');
        await tester.pump();
        await tester.pumpAndSettle();

        final strings = container.read(stringsProvider);
        expect(find.text(strings.activeSessionInviteTitle), findsOneWidget);

        // Tap "Leave & Go to Room"
        await tester.tap(
          find.widgetWithText(NeonButton, strings.leaveAndJoinNew),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify leaveRoom was called on active session
        expect(fakeRoomService.leaveCallCount, 1);
        expect(fakeRoomService.lastLeftRoomCode, 'ACTIVE2');
        expect(fakeRoomService.lastIsMatch, isTrue);

        // Verify navigated to JoinRoomScreen with prefilled code
        expect(find.byType(JoinRoomScreen), findsOneWidget);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'SUCC88');

        await controller.close();
      },
    );

    testWidgets(
      'Active session: leaveRoom failure blocks navigation, shows Retry/Cancel without "leave anyway"',
      (tester) async {
        final controller = StreamController<String>.broadcast();
        final fakeService = FakeDeepLinkService(stream: controller.stream);
        final fakeRoomService = FakeRoomService(
          leaveResult: const LeaveRoomFailure('network error'),
        );

        final container = ProviderContainer(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
            roomServiceProvider.overrideWithValue(fakeRoomService),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(activeSessionProvider.notifier)
            .setActiveSession(
              const ActiveSession(
                roomCode: 'ACTIVE3',
                isHost: false,
                isInGame: true,
              ),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const DeepLinkCoordinator(
                child: Scaffold(body: Text('Active Match Running')),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Incoming link arrives
        controller.add('FAIL77');
        await tester.pump();
        await tester.pumpAndSettle();

        final strings = container.read(stringsProvider);

        // Tap "Leave & Go to Room"
        await tester.tap(
          find.widgetWithText(NeonButton, strings.leaveAndJoinNew),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // leaveRoom was called and failed
        expect(fakeRoomService.leaveCallCount, 1);

        // Must show error dialog with Retry and Cancel ONLY, NO "leave anyway"
        expect(find.text(strings.leaveErrorConnection), findsOneWidget);
        expect(find.text(strings.retry), findsOneWidget);
        expect(find.text(strings.cancel), findsOneWidget);
        expect(find.text(strings.leaveAnyway), findsNothing);

        // Screen was NOT navigated to JoinRoomScreen
        expect(find.byType(JoinRoomScreen), findsNothing);
        expect(find.text('Active Match Running'), findsOneWidget);

        // Tapping Cancel dismisses error dialog and remains in active session
        await tester.tap(find.text(strings.cancel));
        await tester.pumpAndSettle();

        expect(find.byType(JoinRoomScreen), findsNothing);
        expect(find.text('Active Match Running'), findsOneWidget);

        await controller.close();
      },
    );
  });
}
