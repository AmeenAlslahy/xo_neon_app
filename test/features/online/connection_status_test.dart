import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/l10n/locale_providers.dart';
import 'package:xo_neon_app/features/online/application/connection_status_provider.dart';
import 'package:xo_neon_app/features/online/presentation/widgets/connection_status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectionController Tests', () {
    test('initial state and setStatus transitions correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(connectionStatusProvider.notifier);
      expect(controller.lastConnectedAt, isNull);

      controller.setStatus(ConnectionStatus.connected);
      expect(
        container.read(connectionStatusProvider),
        ConnectionStatus.connected,
      );
      final connectedTimestamp = controller.lastConnectedAt;
      expect(connectedTimestamp, isNotNull);

      // Transition to reconnecting preserves last connected timestamp
      controller.setStatus(ConnectionStatus.reconnecting);
      expect(
        container.read(connectionStatusProvider),
        ConnectionStatus.reconnecting,
      );
      expect(controller.lastConnectedAt, connectedTimestamp);

      // Transition to disconnected
      controller.setStatus(ConnectionStatus.disconnected);
      expect(
        container.read(connectionStatusProvider),
        ConnectionStatus.disconnected,
      );
      expect(controller.lastConnectedAt, connectedTimestamp);
    });

    testWidgets('ConnectionStatusBadge renders compact dot without label by default', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectionStatusBadge(),
            ),
          ),
        ),
      );

      expect(find.byType(ConnectionStatusBadge), findsOneWidget);
      // Compact mode should not render text widget to preserve space
      expect(find.text('متصل'), findsNothing);
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('ConnectionStatusBadge renders all 4 states in Arabic with showLabel: true', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localeInitialProvider.overrideWithValue(true), // Arabic
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectionStatusBadge(showLabel: true),
            ),
          ),
        ),
      );

      final notifier = container.read(connectionStatusProvider.notifier);

      // 1. Connected
      notifier.setStatus(ConnectionStatus.connected);
      await tester.pump();
      expect(find.text('متصل'), findsOneWidget);

      // 2. Connecting
      notifier.setStatus(ConnectionStatus.connecting);
      await tester.pump();
      expect(find.text('جارٍ الاتصال...'), findsOneWidget);

      // 3. Reconnecting
      notifier.setStatus(ConnectionStatus.reconnecting);
      await tester.pump();
      expect(find.text('إعادة الاتصال...'), findsOneWidget);

      // 4. Disconnected
      notifier.setStatus(ConnectionStatus.disconnected);
      await tester.pump();
      expect(find.text('غير متصل'), findsOneWidget);
    });

    testWidgets('ConnectionStatusBadge renders in English when locale is toggled', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localeInitialProvider.overrideWithValue(false), // English
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectionStatusBadge(showLabel: true),
            ),
          ),
        ),
      );

      final notifier = container.read(connectionStatusProvider.notifier);

      // Connected in English
      notifier.setStatus(ConnectionStatus.connected);
      await tester.pump();
      expect(find.text('Connected'), findsOneWidget);

      // Disconnected in English
      notifier.setStatus(ConnectionStatus.disconnected);
      await tester.pump();
      expect(find.text('Disconnected'), findsOneWidget);
    });
  });
}
