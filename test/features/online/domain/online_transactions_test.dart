import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/models/cell_position.dart';
import 'package:xo_neon_app/features/game/domain/models/player.dart';
import 'package:xo_neon_app/features/online/application/online_match_service.dart';
import 'package:xo_neon_app/features/online/application/room_service.dart';
import 'package:xo_neon_app/features/online/domain/logic/online_transactions.dart';
import 'package:xo_neon_app/features/online/domain/models/online_game_state.dart';
import 'package:xo_neon_app/features/online/domain/models/room_config.dart';
import 'package:xo_neon_app/features/online/domain/models/room_model.dart';
import 'fake_firebase_database.dart';

void main() {
  group('ONLINE-SAFETY-02: Atomic Transactions Evaluation Tests', () {
    final standardConfig = RoomConfig.standard3x3();

    // ========================================================================
    // 1. Join Room Transaction Tests
    // ========================================================================
    group('1. evaluateJoinRoomTransaction', () {
      final initialWaitingMap = {
        'code': 'ROOM01',
        'hostUid': 'host_1',
        'hostName': 'Host Player',
        'guestUid': null,
        'guestName': null,
        'config': standardConfig.toMap(),
        'status': RoomStatus.waitingForGuest.name,
        'createdAtMs': 1000,
        'lastActiveMs': 1000,
      };

      test('Simultaneous joins: first guest succeeds, second simultaneous guest gets AlreadyFull', () {
        // Guest 1 joins first
        final outcome1 = evaluateJoinRoomTransaction(
          currentData: initialWaitingMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'First Guest',
          nowMs: 1100,
        );

        expect(outcome1, isA<RoomJoinTransactionSuccess>());
        final success1 = outcome1 as RoomJoinTransactionSuccess;
        expect(success1.updatedRoom.guestUid, 'guest_1');
        expect(success1.updatedRoom.status, RoomStatus.ready);

        // Guest 2 attempts to join on the state produced by Guest 1's commit
        final outcome2 = evaluateJoinRoomTransaction(
          currentData: success1.updatedMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_2',
          guestName: 'Second Guest',
          nowMs: 1105,
        );

        expect(outcome2, isA<RoomJoinTransactionAbort>());
        final abort2 = outcome2 as RoomJoinTransactionAbort;
        expect(abort2.failureReason, isA<JoinRoomAlreadyFull>());
      });

      test('Host re-entering the room succeeds without overwriting guest seat', () {
        final withGuestMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['guestUid'] = 'guest_1'
          ..['guestName'] = 'First Guest'
          ..['status'] = RoomStatus.ready.name;

        final outcome = evaluateJoinRoomTransaction(
          currentData: withGuestMap,
          normalizedCode: 'ROOM01',
          guestUid: 'host_1',
          guestName: 'Host Player',
          nowMs: 1200,
        );

        expect(outcome, isA<RoomJoinTransactionSuccess>());
        final success = outcome as RoomJoinTransactionSuccess;
        expect(success.updatedRoom.guestUid, 'guest_1');
        expect(success.updatedRoom.isHost('host_1'), isTrue);
      });

      test('ONLINE-JOIN-EVALUATOR-01: Re-entry - Existing guest re-entering ready room succeeds idempotently', () {
        final readyMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['guestUid'] = 'guest_1'
          ..['guestName'] = 'First Guest'
          ..['status'] = RoomStatus.ready.name;

        final outcome = evaluateJoinRoomTransaction(
          currentData: readyMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'First Guest',
          nowMs: 1250,
        );

        expect(outcome, isA<RoomJoinTransactionSuccess>());
        final success = outcome as RoomJoinTransactionSuccess;
        expect(success.updatedRoom.guestUid, 'guest_1');
        expect(success.updatedRoom.status, RoomStatus.ready);
        expect(success.updatedMap['guestUid'], 'guest_1');
        expect(success.updatedMap['status'], RoomStatus.ready.name);
      });

      test('ONLINE-JOIN-EVALUATOR-01: Re-entry - Existing guest re-entering inGame room succeeds without mutating game state', () {
        final inGameMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['guestUid'] = 'guest_1'
          ..['guestName'] = 'First Guest'
          ..['status'] = RoomStatus.inGame.name
          ..['game'] = {
            'currentRound': 1,
            'currentTurn': 'x',
            'hostScore': 0,
            'guestScore': 0,
            'moves': <dynamic>[],
            'status': 'playing',
            'lastUpdatedMs': 1200,
          };

        final outcome = evaluateJoinRoomTransaction(
          currentData: inGameMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'First Guest',
          nowMs: 1260,
        );

        expect(outcome, isA<RoomJoinTransactionSuccess>());
        final success = outcome as RoomJoinTransactionSuccess;
        expect(success.updatedRoom.guestUid, 'guest_1');
        expect(success.updatedRoom.status, RoomStatus.inGame);
        expect(success.updatedRoom.game, isNotNull);
        expect(success.updatedMap['game'], isNotNull);
        expect(success.updatedMap['status'], RoomStatus.inGame.name);
      });

      test('ONLINE-JOIN-EVALUATOR-01: Re-entry - Existing host re-entering inGame room succeeds without mutating game state', () {
        final inGameMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['guestUid'] = 'guest_1'
          ..['guestName'] = 'First Guest'
          ..['status'] = RoomStatus.inGame.name
          ..['game'] = {
            'currentRound': 1,
            'currentTurn': 'x',
            'hostScore': 0,
            'guestScore': 0,
            'moves': <dynamic>[],
            'status': 'playing',
            'lastUpdatedMs': 1200,
          };

        final outcome = evaluateJoinRoomTransaction(
          currentData: inGameMap,
          normalizedCode: 'ROOM01',
          guestUid: 'host_1',
          guestName: 'Host Player',
          nowMs: 1270,
        );

        expect(outcome, isA<RoomJoinTransactionSuccess>());
        final success = outcome as RoomJoinTransactionSuccess;
        expect(success.updatedRoom.hostUid, 'host_1');
        expect(success.updatedRoom.guestUid, 'guest_1');
        expect(success.updatedRoom.status, RoomStatus.inGame);
        expect(success.updatedRoom.game, isNotNull);
        expect(success.updatedMap['game'], isNotNull);
        expect(success.updatedMap['status'], RoomStatus.inGame.name);
      });

      test('Joining abandoned or finished room aborts with NotFound', () {
        final abandonedMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = RoomStatus.abandoned.name;

        final outcomeAbandoned = evaluateJoinRoomTransaction(
          currentData: abandonedMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_new',
          guestName: 'New Guest',
          nowMs: 1300,
        );

        expect(outcomeAbandoned, isA<RoomJoinTransactionAbort>());
        expect((outcomeAbandoned as RoomJoinTransactionAbort).failureReason,
            isA<JoinRoomNotFound>());

        final finishedMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = RoomStatus.finished.name;

        final outcomeFinished = evaluateJoinRoomTransaction(
          currentData: finishedMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_new',
          guestName: 'New Guest',
          nowMs: 1300,
        );

        expect(outcomeFinished, isA<RoomJoinTransactionAbort>());
        expect((outcomeFinished as RoomJoinTransactionAbort).failureReason,
            isA<JoinRoomNotFound>());
      });

      test('Missing or non-map room data aborts with NotFound', () {
        final outcomeNull = evaluateJoinRoomTransaction(
          currentData: null,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'Guest',
          nowMs: 1300,
        );

        expect(outcomeNull, isA<RoomJoinTransactionAbort>());
        expect((outcomeNull as RoomJoinTransactionAbort).failureReason,
            isA<JoinRoomNotFound>());
      });

      test('ONLINE-JOIN-EVALUATOR-01: Successful join to waitingForGuest room occupies seat cleanly', () {
        final outcome = evaluateJoinRoomTransaction(
          currentData: initialWaitingMap,
          normalizedCode: 'ROOM01',
          guestUid: 'new_guest_1',
          guestName: 'New Guest',
          nowMs: 1350,
        );

        expect(outcome, isA<RoomJoinTransactionSuccess>());
        final success = outcome as RoomJoinTransactionSuccess;
        expect(success.updatedRoom.guestUid, 'new_guest_1');
        expect(success.updatedRoom.guestName, 'New Guest');
        expect(success.updatedRoom.status, RoomStatus.ready);
        expect(success.updatedMap['status'], RoomStatus.ready.name);
        expect(success.updatedMap['guestUid'], 'new_guest_1');
      });

      test('ONLINE-JOIN-EVALUATOR-01: Reject room in inGame status even when guestUid is null', () {
        final inGameNoGuestMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = RoomStatus.inGame.name
          ..['guestUid'] = null
          ..['guestName'] = null;

        final outcome = evaluateJoinRoomTransaction(
          currentData: inGameNoGuestMap,
          normalizedCode: 'ROOM01',
          guestUid: 'stranger_guest',
          guestName: 'Stranger',
          nowMs: 1400,
        );

        expect(outcome, isA<RoomJoinTransactionAbort>());
        final abort = outcome as RoomJoinTransactionAbort;
        expect(abort.failureReason, isA<JoinRoomError>());
        final error = abort.failureReason as JoinRoomError;
        expect(error.reason, JoinRoomFailureReason.roomUnavailable);
      });

      test('ONLINE-JOIN-EVALUATOR-01: Reject room in ready status when new guest attempts to join', () {
        // Case A: ready with guestUid null
        final readyNoGuestMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = RoomStatus.ready.name
          ..['guestUid'] = null
          ..['guestName'] = null;

        final outcomeNoGuest = evaluateJoinRoomTransaction(
          currentData: readyNoGuestMap,
          normalizedCode: 'ROOM01',
          guestUid: 'new_guest',
          guestName: 'New Guest',
          nowMs: 1450,
        );

        expect(outcomeNoGuest, isA<RoomJoinTransactionAbort>());
        final abortNoGuest = outcomeNoGuest as RoomJoinTransactionAbort;
        expect(abortNoGuest.failureReason, isA<JoinRoomError>());
        expect((abortNoGuest.failureReason as JoinRoomError).reason,
            JoinRoomFailureReason.roomUnavailable);

        // Case B: ready with another guest already in seat
        final readyWithGuestMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = RoomStatus.ready.name
          ..['guestUid'] = 'existing_guest'
          ..['guestName'] = 'Existing Guest';

        final outcomeWithGuest = evaluateJoinRoomTransaction(
          currentData: readyWithGuestMap,
          normalizedCode: 'ROOM01',
          guestUid: 'second_new_guest',
          guestName: 'Second Guest',
          nowMs: 1460,
        );

        expect(outcomeWithGuest, isA<RoomJoinTransactionAbort>());
        final abortWithGuest = outcomeWithGuest as RoomJoinTransactionAbort;
        expect(abortWithGuest.failureReason, isA<JoinRoomAlreadyFull>());
      });

      test('ONLINE-JOIN-EVALUATOR-01: Reject room with invalid, non-string, or missing status', () {
        // Case A: missing status key
        final missingStatusMap = Map<String, dynamic>.from(initialWaitingMap)
          ..remove('status');

        final outcomeMissing = evaluateJoinRoomTransaction(
          currentData: missingStatusMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'Guest',
          nowMs: 1500,
        );

        expect(outcomeMissing, isA<RoomJoinTransactionAbort>());
        expect((outcomeMissing as RoomJoinTransactionAbort).failureReason,
            isA<JoinRoomNotFound>());

        // Case B: status is null
        final nullStatusMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = null;

        final outcomeNullStatus = evaluateJoinRoomTransaction(
          currentData: nullStatusMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'Guest',
          nowMs: 1510,
        );

        expect(outcomeNullStatus, isA<RoomJoinTransactionAbort>());
        expect((outcomeNullStatus as RoomJoinTransactionAbort).failureReason,
            isA<JoinRoomNotFound>());

        // Case C: unrecognized string status
        final corruptedStatusMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = 'corrupted_status_xyz';

        final outcomeCorrupted = evaluateJoinRoomTransaction(
          currentData: corruptedStatusMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'Guest',
          nowMs: 1520,
        );

        expect(outcomeCorrupted, isA<RoomJoinTransactionAbort>());
        expect((outcomeCorrupted as RoomJoinTransactionAbort).failureReason,
            isA<JoinRoomNotFound>());

        // Case D: status is non-string (int)
        final nonStringStatusMap = Map<String, dynamic>.from(initialWaitingMap)
          ..['status'] = 12345;

        final outcomeNonString = evaluateJoinRoomTransaction(
          currentData: nonStringStatusMap,
          normalizedCode: 'ROOM01',
          guestUid: 'guest_1',
          guestName: 'Guest',
          nowMs: 1530,
        );

        expect(outcomeNonString, isA<RoomJoinTransactionAbort>());
        expect((outcomeNonString as RoomJoinTransactionAbort).failureReason,
            isA<JoinRoomNotFound>());
      });
    });

    // ========================================================================
    // 2. Submit Move Transaction Tests
    // ========================================================================
    group('2. evaluateSubmitMoveTransaction', () {
      final baseRoom = RoomModel(
        code: 'MATCH01',
        hostUid: 'host_1',
        hostName: 'HostPlayer',
        guestUid: 'guest_2',
        guestName: 'GuestPlayer',
        config: standardConfig,
        status: RoomStatus.inGame,
        createdAtMs: 1000,
        lastActiveMs: 1000,
      );

      final initialGame = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: const [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 1000,
      );

      test('Simultaneous moves by same player: one succeeds, subsequent attempt on updated turn fails with notYourTurn', () {
        // Move 1 by Player X at (0, 0)
        final outcome1 = evaluateSubmitMoveTransaction(
          currentData: initialGame.toMap(),
          position: const Position(0, 0),
          player: Player.x,
          room: baseRoom,
          nowMs: 1100,
        );

        expect(outcome1, isA<SubmitMoveTransactionSuccess>());
        final success1 = outcome1 as SubmitMoveTransactionSuccess;
        expect(success1.nextState.moves.length, 1);
        expect(success1.nextState.currentTurn, Player.o); // Turn swapped to O
        expect(success1.nextState.hostScore, 0);

        // Player X tries a simultaneous second move at (0, 1) against the updated state
        final outcome2 = evaluateSubmitMoveTransaction(
          currentData: success1.nextMap,
          position: const Position(0, 1),
          player: Player.x, // Still X
          room: baseRoom,
          nowMs: 1105,
        );

        expect(outcome2, isA<SubmitMoveTransactionAbort>());
        final abort2 = outcome2 as SubmitMoveTransactionAbort;
        expect(abort2.reason, SubmitMoveFailureReason.notYourTurn);
      });

      test('Simultaneous moves on same cell: second move fails with cellTaken', () {
        // First move commits (0, 0) for X
        final outcome1 = evaluateSubmitMoveTransaction(
          currentData: initialGame.toMap(),
          position: const Position(0, 0),
          player: Player.x,
          room: baseRoom,
          nowMs: 1100,
        );
        final stateAfterMove1 = (outcome1 as SubmitMoveTransactionSuccess).nextMap;

        // Player O tries to play on the same cell (0, 0)
        final outcome2 = evaluateSubmitMoveTransaction(
          currentData: stateAfterMove1,
          position: const Position(0, 0),
          player: Player.o,
          room: baseRoom,
          nowMs: 1110,
        );

        expect(outcome2, isA<SubmitMoveTransactionAbort>());
        final abort2 = outcome2 as SubmitMoveTransactionAbort;
        expect(abort2.reason, SubmitMoveFailureReason.cellTaken);
      });

      test('Submitting move when game status is not playing aborts with notPlaying', () {
        final finishedGame = initialGame.copyWith(
          status: OnlineGameStatus.matchOver,
        );

        final outcome = evaluateSubmitMoveTransaction(
          currentData: finishedGame.toMap(),
          position: const Position(1, 1),
          player: Player.x,
          room: baseRoom,
          nowMs: 1200,
        );

        expect(outcome, isA<SubmitMoveTransactionAbort>());
        expect((outcome as SubmitMoveTransactionAbort).reason,
            SubmitMoveFailureReason.notPlaying);
      });

      test('Submitting move when game node is null aborts with gameMissing', () {
        final outcome = evaluateSubmitMoveTransaction(
          currentData: null,
          position: const Position(1, 1),
          player: Player.x,
          room: baseRoom,
          nowMs: 1200,
        );

        expect(outcome, isA<SubmitMoveTransactionAbort>());
        expect((outcome as SubmitMoveTransactionAbort).reason,
            SubmitMoveFailureReason.gameMissing);
      });

      test('Winning move increments score and switches status to matchOver if target rounds reached', () {
        // Player X has two in a row: (0,0) and (0,1)
        final gameWithTwoMoves = initialGame.copyWith(
          moves: [
            const OnlineMove(row: 0, col: 0, player: Player.x, timestampMs: 100),
            const OnlineMove(row: 1, col: 0, player: Player.o, timestampMs: 110),
            const OnlineMove(row: 0, col: 1, player: Player.x, timestampMs: 120),
            const OnlineMove(row: 1, col: 1, player: Player.o, timestampMs: 130),
          ],
          currentTurn: Player.x,
        );

        // Player X completes winning line at (0, 2)
        final outcome = evaluateSubmitMoveTransaction(
          currentData: gameWithTwoMoves.toMap(),
          position: const Position(0, 2),
          player: Player.x,
          room: baseRoom, // standard3x3 roundsToWin = 1
          nowMs: 1400,
        );

        expect(outcome, isA<SubmitMoveTransactionSuccess>());
        final success = outcome as SubmitMoveTransactionSuccess;
        expect(success.nextState.status, OnlineGameStatus.matchOver);
        expect(success.nextState.roundWinner, Player.x);
        expect(success.nextState.hostScore, 1);
        expect(success.nextState.guestScore, 0);
      });
    });

    // ========================================================================
    // 3. Start Match Atomic Transaction Tests
    // ========================================================================
    group('3. evaluateStartMatchTransaction', () {
      final readyRoomMap = {
        'code': 'START01',
        'hostUid': 'host_1',
        'hostName': 'HostPlayer',
        'guestUid': 'guest_2',
        'guestName': 'GuestPlayer',
        'config': standardConfig.toMap(),
        'status': RoomStatus.ready.name,
        'createdAtMs': 1000,
        'lastActiveMs': 1000,
      };

      test('Atomic start writes status = inGame and creates game = initialState in single operation', () {
        final outcome = evaluateStartMatchTransaction(
          currentData: readyRoomMap,
          normalizedCode: 'START01',
          hostUid: 'host_1',
          nowMs: 2000,
        );

        expect(outcome, isA<StartMatchTransactionSuccess>());
        final success = outcome as StartMatchTransactionSuccess;
        expect(success.updatedRoom.status, RoomStatus.inGame);
        expect(success.updatedMap['status'], RoomStatus.inGame.name);

        final gameMap = success.updatedMap['game'];
        expect(gameMap, isNotNull);
        expect(gameMap['status'], OnlineGameStatus.playing.name);
        expect(gameMap['currentRound'], 1);
        expect(gameMap['currentTurn'], 'X');
      });

      test('Prevent duplicate start: calling start when already inGame aborts with alreadyInGame without overwriting game', () {
        // Start 1 succeeds
        final outcome1 = evaluateStartMatchTransaction(
          currentData: readyRoomMap,
          normalizedCode: 'START01',
          hostUid: 'host_1',
          nowMs: 2000,
        );
        final stateAfterStart1 = (outcome1 as StartMatchTransactionSuccess).updatedMap;

        // Simulate some moves played in the match
        final inGameMovesMap = Map<String, dynamic>.from(stateAfterStart1);
        (inGameMovesMap['game'] as Map)['moves'] = [
          {'row': 1, 'col': 1, 'player': 'X', 'timestampMs': 2100}
        ];

        // Start 2 called concurrently or re-triggered
        final outcome2 = evaluateStartMatchTransaction(
          currentData: inGameMovesMap,
          normalizedCode: 'START01',
          hostUid: 'host_1',
          nowMs: 2200,
        );

        expect(outcome2, isA<StartMatchTransactionAbort>());
        final abort = outcome2 as StartMatchTransactionAbort;
        expect(abort.reason, StartMatchFailureReason.alreadyInGame);

        // Verification: The moves played were NOT overwritten or reset
        expect((inGameMovesMap['game'] as Map)['moves'], isNotEmpty);
      });

      test('Guest vacating seat before start aborts with guestMissing and does NOT write game', () {
        // Guest dropped, leaving guestUid null
        final guestVacatedMap = Map<String, dynamic>.from(readyRoomMap)
          ..['guestUid'] = null
          ..['status'] = RoomStatus.waitingForGuest.name;

        final outcome = evaluateStartMatchTransaction(
          currentData: guestVacatedMap,
          normalizedCode: 'START01',
          hostUid: 'host_1',
          nowMs: 2000,
        );

        expect(outcome, isA<StartMatchTransactionAbort>());
        expect((outcome as StartMatchTransactionAbort).reason,
            StartMatchFailureReason.guestMissing);
        expect(guestVacatedMap['game'], isNull);
      });

      test('Non-host attempting start aborts with notHost', () {
        final outcome = evaluateStartMatchTransaction(
          currentData: readyRoomMap,
          normalizedCode: 'START01',
          hostUid: 'impostor_uid',
          nowMs: 2000,
        );

        expect(outcome, isA<StartMatchTransactionAbort>());
        expect((outcome as StartMatchTransactionAbort).reason,
            StartMatchFailureReason.notHost);
      });
    });

    // ========================================================================
    // 4. Concurrency & Atomicity Tests (Real FakeFirebaseDatabase Mutex Lock)
    // ========================================================================
    group('4. Concurrency & Atomicity End-to-End Tests', () {
      late FakeFirebaseDatabase fakeDb;
      late RoomService roomService;
      late OnlineMatchService matchService;

      setUp(() {
        fakeDb = FakeFirebaseDatabase();
        roomService = RoomService(database: fakeDb);
        matchService = OnlineMatchService(database: fakeDb);
      });

      // ١. سباق الانضمام — صاعد فائز واحد فقط
      test('1. Join race: concurrent joins result in exactly one winner, loser gets AlreadyFull', () async {
        const roomId = 'ABC234';
        final roomRef = fakeDb.ref('rooms/$roomId');
        await roomRef.set({
          'code': roomId,
          'hostUid': 'host1',
          'hostName': 'Host',
          'status': RoomStatus.waitingForGuest.name,
          'config': standardConfig.toMap(),
          'createdAtMs': 1000,
          'lastActiveMs': 1000,
        });

        final results = await Future.wait<JoinRoomResult>([
          roomService.joinRoom(rawCode: roomId, guestUid: 'userA', guestName: 'A'),
          roomService.joinRoom(rawCode: roomId, guestUid: 'userB', guestName: 'B'),
        ], eagerError: false);

        final successes = results.where((r) => r.isSuccess).toList();
        expect(successes.length, 1);
        expect(successes.first.guestUid, anyOf('userA', 'userB'));

        final failures = results.where((r) => !r.isSuccess).toList();
        expect(failures.length, 1);
        expect(failures.first, isA<JoinRoomAlreadyFull>());

        final finalRoomSnap = await roomRef.get();
        final finalRoom = RoomModel.fromMap(roomId, finalRoomSnap.value as Map);
        expect(finalRoom.guestUid, successes.first.guestUid);
        expect(finalRoom.status, RoomStatus.ready);
      });

      // ٢. سباق الحركة — صاعد فائز واحد فقط
      test('2. Move race: concurrent moves result in exactly one committed move', () async {
        const roomId = 'ABC234';
        final roomRef = fakeDb.ref('rooms/$roomId');
        final gameRef = fakeDb.ref('rooms/$roomId/game');

        await roomRef.set({
          'code': roomId,
          'hostUid': 'host1',
          'hostName': 'Host',
          'guestUid': 'guest1',
          'guestName': 'Guest',
          'status': RoomStatus.inGame.name,
          'config': standardConfig.toMap(),
          'createdAtMs': 1000,
          'lastActiveMs': 1000,
        });

        final initialGame = OnlineGameState(
          currentRound: 1,
          currentTurn: Player.x,
          hostScore: 0,
          guestScore: 0,
          moves: const [],
          status: OnlineGameStatus.playing,
          lastUpdatedMs: 1000,
        );
        await gameRef.set(initialGame.toMap());

        final currentRoomSnap = await roomRef.get();
        final currentRoom = RoomModel.fromMap(roomId, currentRoomSnap.value as Map);

        const empty = null;

        final results = await Future.wait<SubmitMoveResult>([
          matchService.submitMove(
            room: currentRoom,
            position: const Position(0, 0),
            player: Player.x,
          ),
          matchService.submitMove(
            room: currentRoom,
            position: const Position(0, 1),
            player: Player.o, // O is not their turn
          ),
        ], eagerError: false);

        final successes = results.where((r) => r.isSuccess).toList();
        expect(successes.length, 1);

        final failures = results.where((r) => !r.isSuccess).toList();
        expect(failures.length, 1);
        expect((failures.first as SubmitMoveFailure).reason, SubmitMoveFailureReason.notYourTurn);

        final gameSnap = await gameRef.get();
        final game = OnlineGameState.fromMap(gameSnap.value as Map);
        // اللوحة تحتوي نقلة واحدة فقط
        expect(game.board.where((c) => c != empty).length, 1);
        expect(game.moves.length, 1);
        expect(game.moves.first.player, Player.x);
      });

      // ٣. اختبار إضافي حرج — الخلية المحجوزة
      test('3. Cell collision: second move on same cell fails with cellTaken', () async {
        const roomId = 'ABC234';
        final roomRef = fakeDb.ref('rooms/$roomId');
        final gameRef = fakeDb.ref('rooms/$roomId/game');

        await roomRef.set({
          'code': roomId,
          'hostUid': 'host1',
          'hostName': 'Host',
          'guestUid': 'guest1',
          'guestName': 'Guest',
          'status': RoomStatus.inGame.name,
          'config': standardConfig.toMap(),
          'createdAtMs': 1000,
          'lastActiveMs': 1000,
        });

        final initialGame = OnlineGameState(
          currentRound: 1,
          currentTurn: Player.x,
          hostScore: 0,
          guestScore: 0,
          moves: const [],
          status: OnlineGameStatus.playing,
          lastUpdatedMs: 1000,
        );
        await gameRef.set(initialGame.toMap());

        final roomSnap = await roomRef.get();
        final currentRoom = RoomModel.fromMap(roomId, roomSnap.value as Map);

        // X يضع في (0,0) بنجاح
        final moveX = await matchService.submitMove(
          room: currentRoom,
          position: const Position(0, 0),
          player: Player.x,
        );
        expect(moveX.isSuccess, isTrue);

        // O يحاول نفس (0,0) → يجب أن يفشل بسبب "cell occupied"
        final moveO = await matchService.submitMove(
          room: currentRoom,
          position: const Position(0, 0),
          player: Player.o,
        );
        expect(moveO.isSuccess, isFalse);
        expect((moveO as SubmitMoveFailure).reason, SubmitMoveFailureReason.cellTaken);

        // لا يجب أن تتحول الخلية إلى O
        final gameSnap = await gameRef.get();
        final game = OnlineGameState.fromMap(gameSnap.value as Map);
        expect(game.board[0], Player.x);
        expect(game.moves.length, 1);
      });

      // ٤. اختبار بدء المباراة الذرّي
      test('4. Atomic match start: room and game are written simultaneously in single update', () async {
        const roomId = 'ABC234';
        final roomRef = fakeDb.ref('rooms/$roomId');

        await roomRef.set({
          'code': roomId,
          'hostUid': 'host1',
          'hostName': 'Host',
          'guestUid': 'guest1',
          'guestName': 'Guest',
          'status': RoomStatus.ready.name,
          'config': standardConfig.toMap(),
          'createdAtMs': 1000,
          'lastActiveMs': 1000,
        });

        // بعد startGame، تلاوة roomRef.get() يجب أن تعطي:
        // - room.status == 'inGame'
        // - room.game != null && room.game.board.length == 9 (3×3)
        // لا يوجد أي إطار زمني يمكن فيه رؤية "inGame بدون game".
        await roomService.startGame(roomCode: roomId, hostUid: 'host1');

        final snap = await roomRef.get();
        final room = RoomModel.fromMap(roomId, snap.value as Map);

        expect(room.status, RoomStatus.inGame);
        expect(room.game, isNotNull);
        expect(room.game!.board.length, 9);
        expect(room.startedAtMs, isNotNull);
      });
    });
  });
}
