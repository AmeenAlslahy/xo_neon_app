import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_service.dart';

/// Provider exposing the singleton [AuthService].
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Manages anonymous authentication for XO Neon online sessions.
class AuthService {
  AuthService({this.auth});

  final FirebaseAuth? auth;
  Future<User?>? _pending;

  FirebaseAuth get _instance => auth ?? FirebaseAuth.instance;

  /// Ensures an authenticated session is active.
  ///
  /// If a user is already signed in (e.g. from a prior app launch), returns
  /// that user. Otherwise performs an anonymous sign-in and returns the new user.
  Future<User?> ensureSignedIn() {
    final current = _safeCurrentUser();
    if (current != null) {
      return _prepareToken(current);
    }
    return _pending ??= _signIn().whenComplete(() => _pending = null);
  }

  Future<User?> _signIn() async {
    try {
      // The injection point (tests) bypasses Firebase entirely; production
      // paths make sure the default app exists before asking for a session.
      if (auth == null) {
        await FirebaseService.initialize();
      }
      final current = _safeCurrentUser();
      if (current != null) {
        return current;
      }
      final cred = await _instance.signInAnonymously();
      final user = cred.user;
      if (user != null) {
        await _loadToken(user);
      }
      return user;
    } catch (_) {
      // In offline or unconfigured environments, returns null gracefully
      return null;
    }
  }

  Future<User> _prepareToken(User user) async {
    await _loadToken(user);
    return user;
  }

  /// Loads the ID token so the Realtime Database client receives the auth
  /// state before its first connection.
  Future<void> _loadToken(User user) async {
    try {
      await user.getIdToken();
    } catch (_) {
      // Offline: the socket can reconnect once the token is available.
    }
  }

  User? _safeCurrentUser() {
    try {
      return _instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Returns the current user's UID, or null if not signed in.
  String? get currentUid {
    try {
      return _instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Whether a user is currently signed in.
  bool get isSignedIn {
    try {
      return _instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }
}
