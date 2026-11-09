import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/online/application/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseService Tests', () {
    test('initialize completes without throwing unhandled exceptions', () async {
      // Calling initialize in unit test environment (even without real platform channels)
      // must handle errors safely and complete without crashing the application.
      await expectLater(FirebaseService.initialize(), completes);
      await expectLater(FirebaseService.initialize(), completes);
    });
  });
}
