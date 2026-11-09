import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider exposing the singleton [AuthService].
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Manages anonymous authentication for XO Neon online sessions.
class AuthService {
  AuthService({this.auth});

  final FirebaseAuth? auth;

  FirebaseAuth get _instance => auth ?? FirebaseAuth.instance;

  /// Ensures an authenticated session is active.
  ///
  /// If a user is already signed in (e.g. from a prior app launch), returns
  /// that user. Otherwise performs an anonymous sign-in and returns the new user.
  Future<User?> ensureSignedIn() async {
    try {
      final current = _instance.currentUser;
      if (current != null) {
        return current;
      }
      final cred = await _instance.signInAnonymously();
      return cred.user;
    } catch (_) {
      // In offline or unconfigured environments, returns null gracefully
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
