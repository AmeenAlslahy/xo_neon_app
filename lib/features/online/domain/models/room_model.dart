import 'online_game_state.dart';
import 'room_config.dart';

/// Lifecycle status of an online match room.
enum RoomStatus {
  waitingForGuest,
  ready,
  inGame,
  abandoned,
  finished;

  static RoomStatus fromString(String? value) {
    return switch (value) {
      'waitingForGuest' => RoomStatus.waitingForGuest,
      'ready' => RoomStatus.ready,
      'inGame' => RoomStatus.inGame,
      'abandoned' => RoomStatus.abandoned,
      'finished' => RoomStatus.finished,
      _ => RoomStatus.waitingForGuest,
    };
  }
}

enum TerminationReason {
  hostLeft('host_left'),
  guestLeft('guest_left'),
  hostDisconnected('host_disconnected'),
  guestDisconnected('guest_disconnected'),
  roomClosed('room_closed'),
  unknown('unknown');

  const TerminationReason(this.wireValue);
  final String wireValue;

  static TerminationReason fromString(String? value) {
    return switch (value) {
      'host_left' || 'hostLeft' => TerminationReason.hostLeft,
      'guest_left' || 'guestLeft' => TerminationReason.guestLeft,
      'host_disconnected' || 'hostDisconnected' => TerminationReason.hostDisconnected,
      'guest_disconnected' || 'guestDisconnected' => TerminationReason.guestDisconnected,
      'room_closed' || 'roomClosed' => TerminationReason.roomClosed,
      _ => TerminationReason.unknown,
    };
  }
}

/// Represents an explicit termination / closure event for a room or match.
class RoomTermination {
  const RoomTermination({
    required this.reason,
    required this.byUid,
    required this.byRole,
    required this.message,
    required this.timestampMs,
  });

  /// Reason code: 'host_left', 'guest_left', 'host_disconnected', etc.
  final String reason;

  /// UID of the player who triggered the termination.
  final String byUid;

  /// Role of the player who triggered the termination ('host', 'guest', or 'system').
  final String byRole;

  /// Human-readable message or banner text.
  final String message;

  /// Epoch millisecond when termination was recorded.
  final int timestampMs;

  TerminationReason get reasonEnum => TerminationReason.fromString(reason);

  bool get isHost => byRole == 'host';
  bool get isGuest => byRole == 'guest';

  Map<String, dynamic> toMap() => {
        'reason': reason,
        'byUid': byUid,
        'byRole': byRole,
        'message': message,
        'timestampMs': timestampMs,
        'atMs': timestampMs,
      };

  factory RoomTermination.fromMap(Map<dynamic, dynamic> map) {
    return RoomTermination(
      reason: (map['reason'] as String?) ?? 'unknown',
      byUid: (map['byUid'] as String?) ?? '',
      byRole: (map['byRole'] as String?) ?? 'host',
      message: (map['message'] as String?) ?? '',
      timestampMs: (map['atMs'] as num?)?.toInt() ??
          (map['timestampMs'] as num?)?.toInt() ??
          0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomTermination &&
          runtimeType == other.runtimeType &&
          reason == other.reason &&
          byUid == other.byUid &&
          byRole == other.byRole &&
          timestampMs == other.timestampMs;

  @override
  int get hashCode => Object.hash(reason, byUid, byRole, timestampMs);
}

/// Domain model representing an active or pending multiplayer room.
class RoomModel {
  const RoomModel({
    required this.code,
    required this.hostUid,
    required this.hostName,
    this.guestUid,
    this.guestName,
    required this.config,
    this.status = RoomStatus.waitingForGuest,
    required this.createdAtMs,
    required this.lastActiveMs,
    this.guestJoinedAtMs,
    this.startedAtMs,
    this.termination,
    this.game,
  });

  /// The unique 6-character room code.
  final String code;

  /// UID of the host player (Mark X).
  final String hostUid;

  /// Display name of the host player.
  final String hostName;

  /// UID of the guest player (Mark O), null until joined.
  final String? guestUid;

  /// Display name of the guest player.
  final String? guestName;

  /// Match rules and board dimensions.
  final RoomConfig config;

  /// Current lifecycle stage of the room.
  final RoomStatus status;

  /// Epoch timestamp when the room was created.
  final int createdAtMs;

  /// Epoch timestamp when the room was last active.
  final int lastActiveMs;

  /// Epoch timestamp when the guest joined the room.
  final int? guestJoinedAtMs;

  /// Epoch timestamp when the match was started.
  final int? startedAtMs;

  /// Explicit termination details if this room was closed/abandoned intentionally.
  final RoomTermination? termination;

  /// Game state if the room is in-game or finished.
  final OnlineGameState? game;

  /// Whether both player slots are occupied.
  bool get isFull => guestUid != null && guestUid!.isNotEmpty;

  /// Whether the room is ready to start a game.
  bool get isReady => status == RoomStatus.ready && isFull;

  /// Whether the room has been abandoned or explicitly terminated.
  bool get isTerminated => status == RoomStatus.abandoned || termination != null;

  /// Whether the given [uid] is the host of this room.
  bool isHost(String uid) => hostUid == uid;

  /// Whether the given [uid] is the guest of this room.
  bool isGuest(String uid) => guestUid == uid;

  /// Whether the given [uid] is a registered participant in this room.
  bool isParticipant(String uid) => isHost(uid) || isGuest(uid);

  RoomModel copyWith({
    String? code,
    String? hostUid,
    String? hostName,
    String? guestUid,
    String? guestName,
    bool clearGuest = false,
    RoomConfig? config,
    RoomStatus? status,
    int? createdAtMs,
    int? lastActiveMs,
    int? guestJoinedAtMs,
    int? startedAtMs,
    RoomTermination? termination,
    bool clearTermination = false,
    OnlineGameState? game,
    bool clearGame = false,
  }) {
    return RoomModel(
      code: code ?? this.code,
      hostUid: hostUid ?? this.hostUid,
      hostName: hostName ?? this.hostName,
      guestUid: clearGuest ? null : (guestUid ?? this.guestUid),
      guestName: clearGuest ? null : (guestName ?? this.guestName),
      config: config ?? this.config,
      status: status ?? this.status,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastActiveMs: lastActiveMs ?? this.lastActiveMs,
      guestJoinedAtMs: guestJoinedAtMs ?? this.guestJoinedAtMs,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      termination: clearTermination ? null : (termination ?? this.termination),
      game: clearGame ? null : (game ?? this.game),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'hostUid': hostUid,
        'hostName': hostName,
        'guestUid': guestUid,
        'guestName': guestName,
        'config': config.toMap(),
        'status': status.name,
        'createdAtMs': createdAtMs,
        'lastActiveMs': lastActiveMs,
        if (guestJoinedAtMs != null) 'guestJoinedAtMs': guestJoinedAtMs,
        if (startedAtMs != null) 'startedAtMs': startedAtMs,
        if (termination != null) 'termination': termination!.toMap(),
        if (game != null) 'game': game!.toMap(),
      };

  factory RoomModel.fromMap(String code, Map<dynamic, dynamic> map) {
    final rawConfig = map['config'];
    final config = rawConfig is Map
        ? RoomConfig.fromMap(rawConfig)
        : RoomConfig.standard3x3();

    RoomTermination? term;
    final rawTerm = map['termination'];
    if (rawTerm is Map) {
      term = RoomTermination.fromMap(rawTerm);
    }

    final rawGame = map['game'];
    OnlineGameState? game;
    if (rawGame is Map) {
      game = OnlineGameState.fromMap(rawGame);
    }

    return RoomModel(
      code: code,
      hostUid: (map['hostUid'] as String?) ?? '',
      hostName: (map['hostName'] as String?) ?? 'Player 1',
      guestUid: map['guestUid'] as String?,
      guestName: map['guestName'] as String?,
      config: config,
      status: RoomStatus.fromString(map['status'] as String?),
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      lastActiveMs: (map['lastActiveMs'] as num?)?.toInt() ?? 0,
      guestJoinedAtMs: (map['guestJoinedAtMs'] as num?)?.toInt(),
      startedAtMs: (map['startedAtMs'] as num?)?.toInt(),
      termination: term,
      game: game,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomModel &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          hostUid == other.hostUid &&
          guestUid == other.guestUid &&
          status == other.status &&
          config == other.config &&
          termination == other.termination;

  @override
  int get hashCode =>
      Object.hash(code, hostUid, guestUid, status, config, termination);
}
