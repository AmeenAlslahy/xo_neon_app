import '../../../game/domain/logic/game_board.dart';
import '../../../game/domain/logic/win_evaluator.dart';
import '../../../game/domain/models/board_config.dart';
import '../../../game/domain/models/cell_position.dart';
import '../../../game/domain/models/player.dart';
import '../models/online_game_state.dart';
import '../models/room_config.dart';
import '../models/room_model.dart';
import '../../application/room_service.dart';

// ============================================================================
// 1. Join Room Transaction Evaluation
// ============================================================================

sealed class RoomJoinTransactionOutcome {
  const RoomJoinTransactionOutcome();
  const factory RoomJoinTransactionOutcome.success({
    required RoomModel updatedRoom,
    required Map<String, dynamic> updatedMap,
  }) = RoomJoinTransactionSuccess;

  const factory RoomJoinTransactionOutcome.abort(
    JoinRoomResult failureReason,
  ) = RoomJoinTransactionAbort;
}

class RoomJoinTransactionSuccess extends RoomJoinTransactionOutcome {
  const RoomJoinTransactionSuccess({
    required this.updatedRoom,
    required this.updatedMap,
  });

  final RoomModel updatedRoom;
  final Map<String, dynamic> updatedMap;
}

class RoomJoinTransactionAbort extends RoomJoinTransactionOutcome {
  const RoomJoinTransactionAbort(this.failureReason);
  final JoinRoomResult failureReason;
}

/// Pure transaction evaluator for joining a room atomically.
RoomJoinTransactionOutcome evaluateJoinRoomTransaction({
  required Object? currentData,
  required String normalizedCode,
  required String guestUid,
  required String guestName,
  required int nowMs,
}) {
  if (currentData == null || currentData is! Map) {
    return const RoomJoinTransactionOutcome.abort(JoinRoomNotFound());
  }

  final currentMap = Map<String, dynamic>.from(currentData);
  final rawStatus = currentMap['status'];

  // Validate raw status explicitly:
  // Must be a recognized non-null string matching valid RoomStatus names.
  const validStatusNames = {
    'waitingForGuest',
    'ready',
    'inGame',
    'abandoned',
    'finished',
  };

  if (rawStatus is! String || !validStatusNames.contains(rawStatus)) {
    return const RoomJoinTransactionOutcome.abort(JoinRoomNotFound());
  }

  final currentRoom = RoomModel.fromMap(normalizedCode, currentMap);

  // 1. If status is abandoned or finished -> abort with NotFound
  if (currentRoom.status == RoomStatus.abandoned ||
      currentRoom.status == RoomStatus.finished) {
    return const RoomJoinTransactionOutcome.abort(JoinRoomNotFound());
  }

  // 2. If host re-enters, allow without modifying guest slot
  if (currentRoom.isHost(guestUid)) {
    return RoomJoinTransactionOutcome.success(
      updatedRoom: currentRoom,
      updatedMap: currentMap,
    );
  }

  // 3. If guest is re-entering their own seat, allow without modifying
  if (currentRoom.isGuest(guestUid)) {
    return RoomJoinTransactionOutcome.success(
      updatedRoom: currentRoom,
      updatedMap: currentMap,
    );
  }

  // 4. If guest slot is occupied by someone else -> abort with AlreadyFull
  if (currentRoom.guestUid != null && currentRoom.guestUid!.isNotEmpty) {
    return const RoomJoinTransactionOutcome.abort(JoinRoomAlreadyFull());
  }

  // 5. A NEW guest can ONLY join if the room is explicitly waitingForGuest.
  // Explicitly reject inGame, ready, or any non-waiting status even if guestUid is null.
  if (currentRoom.status != RoomStatus.waitingForGuest ||
      rawStatus != RoomStatus.waitingForGuest.name) {
    return const RoomJoinTransactionOutcome.abort(
      JoinRoomError(JoinRoomFailureReason.roomUnavailable),
    );
  }

  // 6. Occupy the slot cleanly
  final updated = currentRoom.copyWith(
    guestUid: guestUid,
    guestName: guestName,
    status: RoomStatus.ready,
    guestJoinedAtMs: nowMs,
    lastActiveMs: nowMs,
  );

  currentMap['guestUid'] = guestUid;
  currentMap['guestName'] = guestName;
  currentMap['status'] = RoomStatus.ready.name;
  currentMap['guestJoinedAtMs'] = nowMs;
  currentMap['lastActiveMs'] = nowMs;

  return RoomJoinTransactionOutcome.success(
    updatedRoom: updated,
    updatedMap: currentMap,
  );
}

// ============================================================================
// 2. Submit Move Transaction Evaluation
// ============================================================================

enum SubmitMoveFailureReason {
  gameMissing,
  notPlaying,
  notYourTurn,
  cellTaken,
  transactionAborted,
}

sealed class SubmitMoveResult {
  const SubmitMoveResult();
  bool get isSuccess => this is SubmitMoveSuccess;
}

class SubmitMoveSuccess extends SubmitMoveResult {
  const SubmitMoveSuccess(this.nextState);
  final OnlineGameState nextState;
}

class SubmitMoveFailure extends SubmitMoveResult {
  const SubmitMoveFailure(this.reason);
  final SubmitMoveFailureReason reason;
}

sealed class SubmitMoveTransactionOutcome {
  const SubmitMoveTransactionOutcome();
  const factory SubmitMoveTransactionOutcome.success({
    required OnlineGameState nextState,
    required Map<String, dynamic> nextMap,
  }) = SubmitMoveTransactionSuccess;

  const factory SubmitMoveTransactionOutcome.abort(
    SubmitMoveFailureReason reason,
  ) = SubmitMoveTransactionAbort;
}

class SubmitMoveTransactionSuccess extends SubmitMoveTransactionOutcome {
  const SubmitMoveTransactionSuccess({
    required this.nextState,
    required this.nextMap,
  });

  final OnlineGameState nextState;
  final Map<String, dynamic> nextMap;
}

class SubmitMoveTransactionAbort extends SubmitMoveTransactionOutcome {
  const SubmitMoveTransactionAbort(this.reason);
  final SubmitMoveFailureReason reason;
}

/// Pure transaction evaluator for submitting a move atomically.
SubmitMoveTransactionOutcome evaluateSubmitMoveTransaction({
  required Object? currentData,
  required Position position,
  required Player player,
  required RoomModel room,
  required int nowMs,
}) {
  // 1. Game node missing
  if (currentData == null || currentData is! Map) {
    return const SubmitMoveTransactionOutcome.abort(
      SubmitMoveFailureReason.gameMissing,
    );
  }

  final current = OnlineGameState.fromMap(currentData);

  // 2. Status != playing
  if (current.status != OnlineGameStatus.playing) {
    return const SubmitMoveTransactionOutcome.abort(
      SubmitMoveFailureReason.notPlaying,
    );
  }

  // 3. Current turn != player
  if (current.currentTurn != player) {
    return const SubmitMoveTransactionOutcome.abort(
      SubmitMoveFailureReason.notYourTurn,
    );
  }

  // 4. Cell already occupied
  final alreadyTaken = current.moves.any(
    (m) => m.row == position.row && m.col == position.col,
  );
  if (alreadyTaken) {
    return const SubmitMoveTransactionOutcome.abort(
      SubmitMoveFailureReason.cellTaken,
    );
  }

  // 5. Apply move purely via evaluator
  final nextState = applyOnlineMove(
    current: current,
    position: position,
    player: player,
    roomConfig: room.config,
    nowMs: nowMs,
  );

  return SubmitMoveTransactionOutcome.success(
    nextState: nextState,
    nextMap: nextState.toMap(),
  );
}

/// Pure move evaluator function that applies a move to an [OnlineGameState]
/// and returns the new state without any database side effects.
OnlineGameState applyOnlineMove({
  required OnlineGameState current,
  required Position position,
  required Player player,
  required RoomConfig roomConfig,
  required int nowMs,
  WinEvaluator evaluator = const WinEvaluator(),
}) {
  final newMove = OnlineMove(
    row: position.row,
    col: position.col,
    player: player,
    timestampMs: nowMs,
  );

  final updatedMoves = [...current.moves, newMove];

  final boardConfig = BoardConfig(
    rows: roomConfig.boardSize,
    cols: roomConfig.boardSize,
    winStreak: roomConfig.winStreak,
  );

  var board = GameBoard.empty(boardConfig);
  for (final m in updatedMoves) {
    board = board.copyWithMove(m.position, m.player);
  }

  final winLines = evaluator.findAllWinningLinesFromMove(
    board: board,
    lastMove: position,
    player: player,
  );

  OnlineGameStatus nextStatus;
  Player? roundWinner;
  List<Position>? winningPositions;
  int nextHostScore = current.hostScore;
  int nextGuestScore = current.guestScore;

  if (winLines.isNotEmpty) {
    roundWinner = player;
    winningPositions = winLines.first.positions;

    if (player == Player.x) {
      nextHostScore++;
    } else {
      nextGuestScore++;
    }

    final isMatchOver = nextHostScore >= roomConfig.roundsToWin ||
        nextGuestScore >= roomConfig.roundsToWin;

    nextStatus =
        isMatchOver ? OnlineGameStatus.matchOver : OnlineGameStatus.roundWon;
  } else if (board.isFull) {
    nextStatus = OnlineGameStatus.roundDraw;
  } else {
    nextStatus = OnlineGameStatus.playing;
  }

  final nextTurn = player.other;

  return current.copyWith(
    moves: updatedMoves,
    currentTurn: nextTurn,
    status: nextStatus,
    roundWinner: roundWinner,
    winningPositions: winningPositions,
    hostScore: nextHostScore,
    guestScore: nextGuestScore,
    lastUpdatedMs: nowMs,
  );
}

// ============================================================================
// 3. Start Match Atomic Transaction Evaluation
// ============================================================================

enum StartMatchFailureReason {
  alreadyInGame,
  guestMissing,
  notReady,
  notHost,
  notFound,
  networkError,
}

sealed class StartMatchResult {
  const StartMatchResult();
  bool get isSuccess => this is StartMatchSuccess;
}

class StartMatchSuccess extends StartMatchResult {
  const StartMatchSuccess(this.room);
  final RoomModel room;
}

class StartMatchFailure extends StartMatchResult {
  const StartMatchFailure(this.reason);
  final StartMatchFailureReason reason;
}

sealed class StartMatchTransactionOutcome {
  const StartMatchTransactionOutcome();
  const factory StartMatchTransactionOutcome.success({
    required RoomModel updatedRoom,
    required Map<String, dynamic> updatedMap,
  }) = StartMatchTransactionSuccess;

  const factory StartMatchTransactionOutcome.abort(
    StartMatchFailureReason reason,
  ) = StartMatchTransactionAbort;
}

class StartMatchTransactionSuccess extends StartMatchTransactionOutcome {
  const StartMatchTransactionSuccess({
    required this.updatedRoom,
    required this.updatedMap,
  });

  final RoomModel updatedRoom;
  final Map<String, dynamic> updatedMap;
}

class StartMatchTransactionAbort extends StartMatchTransactionOutcome {
  const StartMatchTransactionAbort(this.reason);
  final StartMatchFailureReason reason;
}

/// Pure transaction evaluator for starting a match atomically.
StartMatchTransactionOutcome evaluateStartMatchTransaction({
  required Object? currentData,
  required String normalizedCode,
  required String hostUid,
  required int nowMs,
}) {
  if (currentData == null || currentData is! Map) {
    return const StartMatchTransactionOutcome.abort(
      StartMatchFailureReason.notFound,
    );
  }

  final currentMap = Map<String, dynamic>.from(currentData);
  final status = currentMap['status'] as String?;

  // 1. If already inGame, reject immediately without touching game
  if (status == RoomStatus.inGame.name) {
    return const StartMatchTransactionOutcome.abort(
      StartMatchFailureReason.alreadyInGame,
    );
  }

  final storedHostUid = currentMap['hostUid'] as String?;
  if (storedHostUid != null && storedHostUid != hostUid) {
    return const StartMatchTransactionOutcome.abort(
      StartMatchFailureReason.notHost,
    );
  }

  // 2. If guest left (guestUid empty or null), reject
  final guestUid = currentMap['guestUid'] as String?;
  if (guestUid == null || guestUid.isEmpty) {
    return const StartMatchTransactionOutcome.abort(
      StartMatchFailureReason.guestMissing,
    );
  }

  // 3. Room must be ready
  if (status != RoomStatus.ready.name) {
    return const StartMatchTransactionOutcome.abort(
      StartMatchFailureReason.notReady,
    );
  }

  // 4. Generate initial game state atomically
  final initialState = OnlineGameState(
    currentRound: 1,
    currentTurn: Player.x,
    hostScore: 0,
    guestScore: 0,
    moves: const [],
    status: OnlineGameStatus.playing,
    lastUpdatedMs: nowMs,
  );

  currentMap['status'] = RoomStatus.inGame.name;
  currentMap['startedAtMs'] = nowMs;
  currentMap['lastActiveMs'] = nowMs;
  currentMap['game'] = initialState.toMap();

  final updatedRoom = RoomModel.fromMap(normalizedCode, currentMap);

  return StartMatchTransactionOutcome.success(
    updatedRoom: updatedRoom,
    updatedMap: currentMap,
  );
}
