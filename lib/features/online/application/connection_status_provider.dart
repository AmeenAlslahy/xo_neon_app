import 'dart:async';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/firebase_options.dart';
import 'auth_service.dart';
import 'firebase_service.dart';

/// Connection states for real-time Firebase services.
enum ConnectionStatus {
  connecting,
  connected,
  disconnected,
  reconnecting,
}

/// Controller managing live connection state against Firebase RTDB.
class ConnectionController extends Notifier<ConnectionStatus> {
  StreamSubscription<DatabaseEvent>? _subscription;
  DateTime? _lastConnectedAt;

  /// Timestamp of the most recent successful connection.
  DateTime? get lastConnectedAt => _lastConnectedAt;

  @override
  ConnectionStatus build() {
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
      _subscription?.cancel();
    });

    // Startup warms Firebase and the anonymous session up in the background;
    // the badge must wait for that shared initialization instead of failing
    // once and showing "disconnected" forever.
    unawaited(_listenToConnection(() => disposed));
    return ConnectionStatus.connecting;
  }

  Future<void> _listenToConnection(bool Function() isDisposed) async {
    try {
      await FirebaseService.initialize();
      if (isDisposed()) {
        return;
      }

      // Establish the anonymous session before the RTDB client is created.
      // Creating the database reference first left the socket unauthenticated
      // on Android until the token was refreshed manually, so every read was
      // rejected with `permission-denied`.
      try {
        await ref.read(authServiceProvider).ensureSignedIn();
      } catch (_) {
        // Offline or unconfigured: the badge below still reports the socket.
      }
      if (isDisposed()) {
        return;
      }

      final databaseUrl = DefaultFirebaseOptions.currentPlatform.databaseURL;
      final db = databaseUrl != null && databaseUrl.isNotEmpty
          ? FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: databaseUrl,
            )
          : FirebaseDatabase.instance;
      final connectedRef = db.ref('.info/connected');
      _subscription = connectedRef.onValue.listen(
        (event) {
          if (isDisposed()) {
            return;
          }
          final isConnected = event.snapshot.value == true;
          debugPrint(
            'XO_CONN value=${event.snapshot.value} '
            'url=${db.databaseURL}',
          );
          if (isConnected) {
            _lastConnectedAt = DateTime.now();
            state = ConnectionStatus.connected;
          } else {
            state = _lastConnectedAt != null
                ? ConnectionStatus.reconnecting
                : ConnectionStatus.disconnected;
          }
        },
        onError: (Object error) {
          debugPrint('XO_CONN error=$error');
          if (!isDisposed()) {
            state = ConnectionStatus.disconnected;
          }
        },
      );
    } catch (_) {
      // Offline, test, or uninitialized Firebase environment fallback
      if (!isDisposed()) {
        state = ConnectionStatus.disconnected;
      }
    }
  }

  /// Manually update status (used for testing or explicit offline toggles).
  void setStatus(ConnectionStatus newStatus) {
    if (newStatus == ConnectionStatus.connected) {
      _lastConnectedAt = DateTime.now();
    }
    state = newStatus;
  }
}

/// Provider exposing current [ConnectionStatus].
final connectionStatusProvider =
    NotifierProvider<ConnectionController, ConnectionStatus>(
  ConnectionController.new,
);
