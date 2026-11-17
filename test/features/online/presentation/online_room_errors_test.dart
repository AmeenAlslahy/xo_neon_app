import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/core/l10n/app_strings.dart';
import 'package:xo_neon_app/core/widgets/neon_button.dart';
import 'package:xo_neon_app/features/online/application/auth_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'package:xo_neon_app/features/online/presentation/screens/create_room_screen.dart';
import 'package:xo_neon_app/features/online/presentation/screens/join_room_screen.dart';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
}

class _FakeAuthService extends Fake implements AuthService {
  _FakeAuthService({this.user});

  final User? user;

  @override
  Future<User?> ensureSignedIn() async => user;

  @override
  String? get currentUid => user?.uid;
}

/// Rejects every transaction with a Firebase error code, matching what RTDB
/// returns when the room is missing or access is denied.
class _FailingDatabase extends Fake implements FirebaseDatabase {
  _FailingDatabase(this.errorCode, {this.message});

  final String errorCode;
  final String? message;

  @override
  DatabaseReference ref([String? path]) =>
      _FailingReference(errorCode, message: message);
}

class _FailingReference extends Fake implements DatabaseReference {
  _FailingReference(this.errorCode, {this.message});

  final String errorCode;
  final String? message;

  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler transactionHandler, {
    bool applyLocally = true,
  }) {
    throw FirebaseException(
      plugin: 'firebase_database',
      code: errorCode,
      message: message,
    );
  }
}

class _RecordingRoomService extends Fake implements RoomService {
  int joinCalls = 0;
  int createCalls = 0;

  @override
  Future<JoinRoomResult> joinRoom({
    required String rawCode,
    required String guestUid,
    String guestName = 'Player 2',
  }) async {
    joinCalls++;
    return const JoinRoomNotFound();
  }

  @override
  Future<RoomModel> createRoom({
    required RoomConfig config,
    required String hostUid,
    String hostName = 'Player 1',
  }) async {
    createCalls++;
    throw StateError('createRoom must not be called without a signed-in user');
  }
}

Widget _app(Widget child, {required List<dynamic> overrides}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(home: child),
  );
}

Future<void> _submitJoin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'ABC234');
  await tester.pump();
  await tester.tap(find.byType(NeonButton));
  await tester.pumpAndSettle();
}

void main() {
  const strings = AppStrings();

  testWidgets('join stops with a clear message when sign-in fails', (
    tester,
  ) async {
    final roomService = _RecordingRoomService();

    await tester.pumpWidget(
      _app(
        const JoinRoomScreen(),
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          roomServiceProvider.overrideWithValue(roomService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _submitJoin(tester);

    expect(find.text(strings.authFailed), findsOneWidget);
    expect(roomService.joinCalls, 0);
  });

  testWidgets(
    'permission-denied becomes a room-unavailable message, never raw text',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const JoinRoomScreen(),
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(user: _FakeUser('test_uid_1234')),
            ),
            roomServiceProvider.overrideWithValue(
              RoomService(database: _FailingDatabase('permission-denied')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await _submitJoin(tester);

      expect(find.text(strings.roomUnavailable), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.textContaining('firebase_database'), findsNothing);
      expect(find.textContaining('Join failed'), findsNothing);
    },
  );

  testWidgets(
    'generic firebase_database permission message is still room-unavailable',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const JoinRoomScreen(),
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(user: _FakeUser('test_uid_1234')),
            ),
            roomServiceProvider.overrideWithValue(
              RoomService(
                database: _FailingDatabase(
                  'firebase_database',
                  message:
                      'Cause: null, Stacktrace: '
                      'java.lang.Exception: Permission denied',
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await _submitJoin(tester);

      expect(find.text(strings.roomUnavailable), findsOneWidget);
      expect(find.textContaining('Permission denied'), findsNothing);
      expect(find.textContaining('firebase_database'), findsNothing);
    },
  );

  testWidgets('network failure becomes a clear connection message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const JoinRoomScreen(),
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(user: _FakeUser('test_uid_1234')),
          ),
          roomServiceProvider.overrideWithValue(
            RoomService(database: _FailingDatabase('network-request-failed')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _submitJoin(tester);

    expect(find.text(strings.networkError), findsOneWidget);
    expect(find.textContaining('network-request-failed'), findsNothing);
  });

  testWidgets('create room stops when sign-in fails and never writes a room', (
    tester,
  ) async {
    final roomService = _RecordingRoomService();

    await tester.pumpWidget(
      _app(
        const CreateRoomScreen(),
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          roomServiceProvider.overrideWithValue(roomService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(NeonButton));
    await tester.pumpAndSettle();

    expect(find.text(strings.authFailed), findsOneWidget);
    expect(roomService.createCalls, 0);
  });
}
