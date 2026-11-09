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

  /// Whether both player slots are occupied.
  bool get isFull => guestUid != null && guestUid!.isNotEmpty;

  /// Whether the room is ready to start a game.
  bool get isReady => status == RoomStatus.ready && isFull;

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
    RoomConfig? config,
    RoomStatus? status,
    int? createdAtMs,
    int? lastActiveMs,
  }) {
    return RoomModel(
      code: code ?? this.code,
      hostUid: hostUid ?? this.hostUid,
      hostName: hostName ?? this.hostName,
      guestUid: guestUid ?? this.guestUid,
      guestName: guestName ?? this.guestName,
      config: config ?? this.config,
      status: status ?? this.status,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastActiveMs: lastActiveMs ?? this.lastActiveMs,
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
      };

  factory RoomModel.fromMap(String code, Map<dynamic, dynamic> map) {
    final rawConfig = map['config'];
    final config = rawConfig is Map
        ? RoomConfig.fromMap(rawConfig)
        : RoomConfig.standard3x3();

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
          config == other.config;

  @override
  int get hashCode => Object.hash(code, hostUid, guestUid, status, config);
}
