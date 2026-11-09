import 'package:firebase_core/firebase_core.dart';
import '../../../app/firebase_options.dart';

/// Central initialization wrapper for Firebase in XO Neon.
class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;

  /// Whether Firebase has been initialized in the current process.
  static bool get isInitialized => _initialized || Firebase.apps.isNotEmpty;

  /// Initializes the default Firebase application if not already initialized.
  static Future<void> initialize({FirebaseOptions? options}) async {
    if (isInitialized) {
      _initialized = true;
      return;
    }

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
    }
  }
}
