import 'package:firebase_core/firebase_core.dart';
import '../../../app/firebase_options.dart';

/// Central initialization wrapper for Firebase in XO Neon.
class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;
  static Future<void>? _initialization;

  /// Whether Firebase has been initialized in the current process.
  static bool get isInitialized => _initialized || Firebase.apps.isNotEmpty;

  /// Initializes the default Firebase application if not already initialized.
  ///
  /// Callers may race (startup warm-up, the connection badge, and the online
  /// room flows); they all share one initialization future instead of issuing
  /// duplicate `initializeApp` calls.
  static Future<void> initialize({FirebaseOptions? options}) {
    if (isInitialized) {
      _initialized = true;
      return Future.value();
    }
    final pending = _initialization;
    if (pending != null) {
      return pending;
    }
    final future = _initialize(options);
    _initialization = future;
    return future;
  }

  static Future<void> _initialize(FirebaseOptions? options) async {
    try {
      await Firebase.initializeApp(
        options: options ?? DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
    } catch (_) {
      // If already initialized by another runner/platform or offline fallback
      if (Firebase.apps.isNotEmpty) {
        _initialized = true;
      }
    } finally {
      _initialization = null;
    }
  }
}
