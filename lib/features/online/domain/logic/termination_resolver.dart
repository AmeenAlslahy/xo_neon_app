import '../../../../core/l10n/app_strings.dart';
import '../models/online_game_state.dart';
import '../models/room_model.dart';

/// Pure resolution result describing whether a session is terminated and why.
class ResolvedTermination {
  const ResolvedTermination({
    required this.isTerminated,
    this.reason,
    this.byUid,
    this.byRole,
    this.customMessage,
  });

  final bool isTerminated;
  final TerminationReason? reason;
  final String? byUid;
  final String? byRole;
  final String? customMessage;

  bool get isHost => byRole == 'host';
  bool get isGuest => byRole == 'guest';

  /// Returns user-facing, localized banner message distinguishing explicit leave from disconnect.
  String getLocalizedMessage(AppStrings strings, {required bool isHost}) {
    if (customMessage != null && customMessage!.trim().isNotEmpty) {
      // In Arabic, preserve custom messages if they match our canonical strings
      if (customMessage == strings.sessionTerminatedByHost) {
        return strings.sessionTerminatedByHost;
      }
    }

    return switch (reason) {
      TerminationReason.hostLeft => isHost
          ? (strings.isArabic ? 'لقد غادرت المباراة' : 'You left the match')
          : strings.hostLeftMatch,
      TerminationReason.guestLeft => !isHost
          ? (strings.isArabic ? 'لقد غادرت المباراة' : 'You left the match')
          : strings.guestLeftMatch,
      TerminationReason.hostDisconnected => isHost
          ? (strings.isArabic ? 'انقطع اتصالك بالخادم' : 'You were disconnected')
          : strings.hostDisconnectedMatch,
      TerminationReason.guestDisconnected => !isHost
          ? (strings.isArabic ? 'انقطع اتصالك بالخادم' : 'You were disconnected')
          : strings.guestDisconnectedMatch,
      TerminationReason.roomClosed => strings.roomClosedMatch,
      _ => (customMessage != null && customMessage!.isNotEmpty)
          ? customMessage!
          : strings.roomClosedMatch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedTermination &&
          runtimeType == other.runtimeType &&
          isTerminated == other.isTerminated &&
          reason == other.reason &&
          byUid == other.byUid &&
          byRole == other.byRole;

  @override
  int get hashCode => Object.hash(isTerminated, reason, byUid, byRole);
}

/// Pure decision function evaluating the room and game state to determine
/// if the session is terminated and pinpoint the exact cause.
ResolvedTermination resolveTermination(RoomModel? room, OnlineGameState? game) {
  if (room == null) {
    return const ResolvedTermination(isTerminated: false);
  }

  // 1. Natural matchOver outcome takes priority over any late disconnect / termination on the room
  final hasNaturalMatchResult = game != null &&
      game.status == OnlineGameStatus.matchOver &&
      (game.roundWinner != null ||
          game.hostScore > 0 ||
          game.guestScore > 0);

  if (hasNaturalMatchResult) {
    return const ResolvedTermination(isTerminated: false);
  }

  // 2. Explicit termination on the room takes precedence if no natural match completion
  if (room.termination != null) {
    final term = room.termination!;
    return ResolvedTermination(
      isTerminated: true,
      reason: term.reasonEnum,
      byUid: term.byUid,
      byRole: term.byRole,
      customMessage: term.message,
    );
  }

  // 3. matchOver is a natural match completion, NOT a termination
  if (game != null && game.status == OnlineGameStatus.matchOver) {
    return const ResolvedTermination(isTerminated: false);
  }

  // Definition of an active match: includes playing as well as inter-round pauses (roundWon, roundDraw)
  final isMatchActive = game != null &&
      (game.status == OnlineGameStatus.playing ||
          game.status == OnlineGameStatus.roundWon ||
          game.status == OnlineGameStatus.roundDraw);

  // 4. Active match with room.status == waitingForGuest OR guestUid == null
  // This detects the guest dropping abruptly during a match (e.g. guest's lobby onDisconnect ran).
  if (isMatchActive &&
      (room.status == RoomStatus.waitingForGuest || room.guestUid == null)) {
    return const ResolvedTermination(
      isTerminated: true,
      reason: TerminationReason.guestDisconnected,
      byRole: 'guest',
    );
  }

  // 5. Active match with room.status == abandoned
  if (isMatchActive && room.status == RoomStatus.abandoned) {
    if (room.guestUid == null) {
      return const ResolvedTermination(
        isTerminated: true,
        reason: TerminationReason.guestDisconnected,
        byRole: 'guest',
      );
    }
    return const ResolvedTermination(
      isTerminated: true,
      reason: TerminationReason.roomClosed,
    );
  }

  // 6. Room marked abandoned without an active match
  if (room.status == RoomStatus.abandoned) {
    return const ResolvedTermination(
      isTerminated: true,
      reason: TerminationReason.roomClosed,
    );
  }

  return const ResolvedTermination(isTerminated: false);
}
