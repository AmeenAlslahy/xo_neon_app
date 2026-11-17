import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents an ongoing active online match or lobby session.
class ActiveSession {
  const ActiveSession({
    required this.roomCode,
    required this.isHost,
    this.isInGame = false,
  });

  final String roomCode;
  final bool isHost;
  final bool isInGame;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveSession &&
          runtimeType == other.runtimeType &&
          roomCode == other.roomCode &&
          isHost == other.isHost &&
          isInGame == other.isInGame;

  @override
  int get hashCode => Object.hash(roomCode, isHost, isInGame);
}

/// State notifier tracking whether the user is actively inside an online lobby or match.
class ActiveSessionNotifier extends Notifier<ActiveSession?> {
  @override
  ActiveSession? build() => null;

  void setActiveSession(ActiveSession session) {
    if (!ref.mounted) return;
    Future.microtask(() {
      if (!ref.mounted) return;
      state = session;
    });
  }

  void clear(String roomCode, {bool onlyIfLobby = false}) {
    if (!ref.mounted) return;
    Future.microtask(() {
      if (!ref.mounted) return;
      if (state?.roomCode == roomCode) {
        if (onlyIfLobby && state?.isInGame == true) {
          return;
        }
        state = null;
      }
    });
  }

  void forceClear() {
    if (!ref.mounted) return;
    Future.microtask(() {
      if (!ref.mounted) return;
      state = null;
    });
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSession?>(
  ActiveSessionNotifier.new,
);
