import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/online/application/auth_service.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;

  FakeUser(this.uid);
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User user;

  FakeUserCredential(this.user);
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _user;
  int signInAnonymouslyCalls = 0;
  bool shouldThrow = false;

  FakeFirebaseAuth({User? initialUser, this.shouldThrow = false})
      : _user = initialUser;

  @override
  User? get currentUser => _user;

  @override
  Future<UserCredential> signInAnonymously() async {
    signInAnonymouslyCalls++;
    if (shouldThrow) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Network error',
      );
    }
    _user = FakeUser('anonymous-uid-12345');
    return FakeUserCredential(_user!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Tests', () {
    test('initial state when not signed in', () {
      final fakeAuth = FakeFirebaseAuth(initialUser: null);
      final auth = AuthService(auth: fakeAuth);

      expect(auth.isSignedIn, isFalse);
      expect(auth.currentUid, isNull);
    });

    test('returns currentUid and isSignedIn when user is already signed in', () {
      final fakeAuth = FakeFirebaseAuth(initialUser: FakeUser('existing-user-777'));
      final auth = AuthService(auth: fakeAuth);

      expect(auth.isSignedIn, isTrue);
      expect(auth.currentUid, 'existing-user-777');
    });

    test('ensureSignedIn returns existing user without calling signInAnonymously', () async {
      final fakeAuth = FakeFirebaseAuth(initialUser: FakeUser('cached-session-999'));
      final auth = AuthService(auth: fakeAuth);

      final user = await auth.ensureSignedIn();

      expect(user, isNotNull);
      expect(user!.uid, 'cached-session-999');
      expect(fakeAuth.signInAnonymouslyCalls, 0);
    });

    test('ensureSignedIn triggers signInAnonymously when currentUser is null', () async {
      final fakeAuth = FakeFirebaseAuth(initialUser: null);
      final auth = AuthService(auth: fakeAuth);

      final user = await auth.ensureSignedIn();

      expect(user, isNotNull);
      expect(user!.uid, 'anonymous-uid-12345');
      expect(fakeAuth.signInAnonymouslyCalls, 1);
      expect(auth.isSignedIn, isTrue);
      expect(auth.currentUid, 'anonymous-uid-12345');
    });

    test('ensureSignedIn handles network/auth exceptions gracefully and returns null', () async {
      final fakeAuth = FakeFirebaseAuth(initialUser: null, shouldThrow: true);
      final auth = AuthService(auth: fakeAuth);

      final user = await auth.ensureSignedIn();

      expect(user, isNull);
      expect(auth.isSignedIn, isFalse);
      expect(auth.currentUid, isNull);
    });

    test('authServiceProvider instantiates correctly in a Riverpod container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(authServiceProvider);
      expect(service, isA<AuthService>());
    });
  });
}
