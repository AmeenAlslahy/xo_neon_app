import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projectId = 'demo-xo-neon';
  const ns = 'demo-xo-neon-default-rtdb';
  const host = '127.0.0.1';
  const port = 9000;

  String makeJwt(String uid) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'none', 'typ': 'JWT'};
    final payload = {
      'iss': 'https://securetoken.google.com/$projectId',
      'aud': projectId,
      'sub': uid,
      'user_id': uid,
      'auth_time': now,
      'iat': now,
      'exp': now + 3600,
    };
    String b64(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${b64(header)}.${b64(payload)}.';
  }

  Future<({int code, dynamic body})> api(
    String path, {
    String method = 'GET',
    dynamic data,
    String? uid,
    bool isAdmin = false,
  }) async {
    final client = HttpClient();
    try {
      final query = isAdmin
          ? 'ns=$ns&access_token=owner'
          : (uid != null ? 'ns=$ns&auth=${makeJwt(uid)}' : 'ns=$ns');
      final uri = Uri.parse('http://$host:$port/$path.json?$query');
      final request = await client.openUrl(method, uri);
      if (data != null) {
        request.headers.contentType = ContentType.json;
        final bytes = utf8.encode(jsonEncode(data));
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close();
      final bodyStr = await response.transform(utf8.decoder).join();
      dynamic parsed;
      try {
        parsed = bodyStr.isNotEmpty ? jsonDecode(bodyStr) : null;
      } catch (_) {
        parsed = bodyStr;
      }
      return (code: response.statusCode, body: parsed);
    } finally {
      client.close();
    }
  }

  bool isEmulatorRunning = false;

  group('SECURITY-01: Firebase RTDB Rules Matrix on Local Emulator', () {
    setUpAll(() async {
      try {
        final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 500));
        await socket.close();
        isEmulatorRunning = true;
        // Clear database before running tests
        await api('rooms', method: 'DELETE', isAdmin: true);
      } catch (_) {
        isEmulatorRunning = false;
        // ignore: avoid_print
        print('NOTE: Firebase RTDB emulator is not running on $host:$port. Skipping local emulator rules matrix.');
      }
    });

    test('4a. Read Privacy Scenarios', () async {
      if (!isEmulatorRunning) return;
      // Setup room for 4a: waitingForGuest
      final createRes = await api('rooms/R4A_DART', method: 'PUT', uid: 'host1', data: {
        'code': 'R4A_DART',
        'hostUid': 'host1',
        'status': 'waitingForGuest',
        'createdAtMs': 1000,
        'lastActiveMs': 1000,
        'config': {'boardSize': 3, 'winStreak': 3, 'roundsToWin': 1},
      });
      expect(createRes.code, 200);

      // 1. Host reads waitingForGuest -> ALLOW
      final r1 = await api('rooms/R4A_DART', uid: 'host1');
      expect(r1.code, 200);

      // 2. Stranger reads waitingForGuest -> ALLOW (discovery)
      final r2 = await api('rooms/R4A_DART', uid: 'stranger1');
      expect(r2.code, 200);

      // Change status to ready with guest1
      await api('rooms/R4A_DART', method: 'PATCH', isAdmin: true, data: {
        'status': 'ready',
        'guestUid': 'guest1',
      });

      // 3. Stranger reads ready -> DENY
      final r3 = await api('rooms/R4A_DART', uid: 'stranger1');
      expect(r3.code, 401);

      // Change status to inGame
      await api('rooms/R4A_DART', method: 'PATCH', isAdmin: true, data: {
        'status': 'inGame',
      });

      // 4. Stranger reads inGame -> DENY
      final r4 = await api('rooms/R4A_DART', uid: 'stranger1');
      expect(r4.code, 401);

      // 5. Host reads inGame -> ALLOW
      final r5 = await api('rooms/R4A_DART', uid: 'host1');
      expect(r5.code, 200);

      // 6. Guest reads inGame -> ALLOW
      final r6 = await api('rooms/R4A_DART', uid: 'guest1');
      expect(r6.code, 200);

      // 7. Unauthenticated reads inGame -> DENY
      final r7 = await api('rooms/R4A_DART', uid: null);
      expect(r7.code, 401);
    });

    test('4b. Write Scenarios — Create & Join', () async {
      if (!isEmulatorRunning) return;
      // 1. Host creates room with hostUid = self -> ALLOW
      final w1 = await api('rooms/R4B_DART', method: 'PUT', uid: 'hostB', data: {
        'code': 'R4B_DART',
        'hostUid': 'hostB',
        'status': 'waitingForGuest',
        'createdAtMs': 2000,
        'lastActiveMs': 2000,
        'config': {'boardSize': 3, 'winStreak': 3, 'roundsToWin': 1},
      });
      expect(w1.code, 200);

      // 2. Another user tries to create same room code -> DENY
      final w2 = await api('rooms/R4B_DART', method: 'PUT', uid: 'attacker', data: {
        'code': 'R4B_DART',
        'hostUid': 'attacker',
        'status': 'waitingForGuest',
        'createdAtMs': 2000,
        'lastActiveMs': 2000,
        'config': {'boardSize': 3, 'winStreak': 3, 'roundsToWin': 1},
      });
      expect(w2.code, 401);

      // 3. Guest joins self while waitingForGuest -> ALLOW
      final w3 = await api('rooms/R4B_DART', method: 'PATCH', uid: 'guestB', data: {
        'guestUid': 'guestB',
        'status': 'ready',
        'guestJoinedAtMs': 2050,
        'lastActiveMs': 2050,
      });
      expect(w3.code, 200);

      // 4. Guest tries to assign third party -> DENY
      await api('rooms/R4B2_DART', method: 'PUT', uid: 'hostB2', data: {
        'code': 'R4B2_DART',
        'hostUid': 'hostB2',
        'status': 'waitingForGuest',
        'createdAtMs': 2000,
        'lastActiveMs': 2000,
        'config': {'boardSize': 3, 'winStreak': 3, 'roundsToWin': 1},
      });
      final w4 = await api('rooms/R4B2_DART', method: 'PATCH', uid: 'guestAttacker', data: {
        'guestUid': 'victimUid',
        'status': 'ready',
      });
      expect(w4.code, 401);

      // 5. Normal user tries hostUid = self in existing room -> DENY
      final w5 = await api('rooms/R4B_DART', method: 'PATCH', uid: 'stranger', data: {
        'hostUid': 'stranger',
      });
      expect(w5.code, 401);

      // 6. Non-member tries to write to game -> DENY
      final w6 = await api('rooms/R4B_DART/game', method: 'PUT', uid: 'stranger', data: {
        'currentRound': 1,
        'currentTurn': 'X',
        'hostScore': 0,
        'guestScore': 0,
        'status': 'playing',
        'lastUpdatedMs': 3000,
      });
      expect(w6.code, 401);
    });

    test('4c. Score Fraud Scenarios', () async {
      if (!isEmulatorRunning) return;
      await api('rooms/R4B_DART', method: 'PATCH', isAdmin: true, data: {'status': 'inGame'});
      await api('rooms/R4B_DART/game', method: 'PUT', uid: 'hostB', data: {
        'currentRound': 1,
        'currentTurn': 'X',
        'hostScore': 0,
        'guestScore': 0,
        'status': 'playing',
        'lastUpdatedMs': 4000,
      });

      // 1. Host tries hostScore: 999 at once -> DENY
      final s1 = await api('rooms/R4B_DART/game', method: 'PATCH', uid: 'hostB', data: {
        'hostScore': 999,
      });
      expect(s1.code, 401);

      // 2. Guest tries to increment hostScore (opponent point) -> DENY
      final s2 = await api('rooms/R4B_DART/game', method: 'PATCH', uid: 'guestB', data: {
        'hostScore': 1,
      });
      expect(s2.code, 401);

      // 3. Guest tries to increment guestScore twice (+2) -> DENY
      final s3 = await api('rooms/R4B_DART/game', method: 'PATCH', uid: 'guestB', data: {
        'guestScore': 2,
      });
      expect(s3.code, 401);

      // Valid increment +1 by host -> ALLOW
      final validHostInc = await api('rooms/R4B_DART/game', method: 'PATCH', uid: 'hostB', data: {
        'hostScore': 1,
      });
      expect(validHostInc.code, 200);

      // 4. Host tries to decrement hostScore -> DENY
      final s4 = await api('rooms/R4B_DART/game', method: 'PATCH', uid: 'hostB', data: {
        'hostScore': 0,
      });
      expect(s4.code, 401);

      // 5. User tries invalid move index (>= 121) -> DENY
      final s5 = await api('rooms/R4B_DART/game/moves/121', method: 'PUT', uid: 'hostB', data: {
        'row': 0,
        'col': 0,
        'player': 'X',
        'timestampMs': 5000,
      });
      expect(s5.code, 401);

      // 6. Host writes round win with roundWinner string and winningPositions -> ALLOW
      final winWrite = await api('rooms/R4B_DART/game', method: 'PATCH', uid: 'hostB', data: {
        'status': 'roundWon',
        'roundWinner': 'X',
        'winningPositions': [
          {'row': 0, 'col': 0},
          {'row': 0, 'col': 1},
          {'row': 0, 'col': 2},
        ],
      });
      expect(winWrite.code, 200);

      // 7. Invalid roundWinner symbol -> DENY
      final invalidWin = await api('rooms/R4B_DART/game', method: 'PATCH', uid: 'hostB', data: {
        'roundWinner': 'INVALID',
      });
      expect(invalidWin.code, 401);
    });

    test('4d. Identity Fraud Scenarios', () async {
      if (!isEmulatorRunning) return;
      // 1. Guest tries to change hostUid -> DENY
      final i1 = await api('rooms/R4B_DART', method: 'PATCH', uid: 'guestB', data: {
        'hostUid': 'guestB',
      });
      expect(i1.code, 401);

      // 2. Host tries to change guestUid to another user -> DENY
      final i2 = await api('rooms/R4B_DART', method: 'PATCH', uid: 'hostB', data: {
        'guestUid': 'anotherGuest',
      });
      expect(i2.code, 401);

      // 3. Guest tries to change guestUid to another user -> DENY
      final i3 = await api('rooms/R4B_DART', method: 'PATCH', uid: 'guestB', data: {
        'guestUid': 'anotherGuest',
      });
      expect(i3.code, 401);

      // Initial termination written by host -> ALLOW
      final tInit = await api('rooms/R4B_DART/termination', method: 'PUT', uid: 'hostB', data: {
        'reason': 'hostLeft',
        'byUid': 'hostB',
        'byRole': 'host',
        'message': 'Host left',
        'timestampMs': 6000,
        'atMs': 6000,
      });
      expect(tInit.code, 200);

      // 4. Any user tries to overwrite termination after it is set -> DENY
      final i4 = await api('rooms/R4B_DART/termination', method: 'PUT', uid: 'guestB', data: {
        'reason': 'guestLeft',
        'byUid': 'guestB',
        'byRole': 'guest',
        'message': 'Overwritten',
        'timestampMs': 7000,
        'atMs': 7000,
      });
      expect(i4.code, 401);
    });

    test('4e. Non-Breakage Scenarios', () async {
      if (!isEmulatorRunning) return;
      // Fresh room R4E_DART
      await api('rooms/R4E_DART', method: 'PUT', uid: 'hostE', data: {
        'code': 'R4E_DART',
        'hostUid': 'hostE',
        'status': 'waitingForGuest',
        'createdAtMs': 8000,
        'lastActiveMs': 8000,
        'config': {'boardSize': 3, 'winStreak': 3, 'roundsToWin': 1, 'turnTimeLimitSeconds': 30},
      });

      // 1. joinRoom from guest -> ALLOW
      final nb1 = await api('rooms/R4E_DART', method: 'PATCH', uid: 'guestE', data: {
        'guestUid': 'guestE',
        'status': 'ready',
        'guestJoinedAtMs': 8100,
        'lastActiveMs': 8100,
      });
      expect(nb1.code, 200);

      // Host starts game -> ALLOW
      await api('rooms/R4E_DART', method: 'PATCH', uid: 'hostE', data: {
        'status': 'inGame',
        'startedAtMs': 8200,
        'lastActiveMs': 8200,
        'game': {
          'currentRound': 1,
          'currentTurn': 'X',
          'hostScore': 0,
          'guestScore': 0,
          'status': 'playing',
          'lastUpdatedMs': 8200,
        },
      });

      // 2. submitMove from host -> ALLOW
      final nb2 = await api('rooms/R4E_DART/game', method: 'PATCH', uid: 'hostE', data: {
        'currentTurn': 'O',
        'lastUpdatedMs': 8300,
        'moves': [
          {'row': 0, 'col': 0, 'player': 'X', 'timestampMs': 8300},
        ],
      });
      expect(nb2.code, 200);

      // 3. submitMove from guest -> ALLOW
      final nb3 = await api('rooms/R4E_DART/game', method: 'PATCH', uid: 'guestE', data: {
        'currentTurn': 'X',
        'lastUpdatedMs': 8400,
        'moves': [
          {'row': 0, 'col': 0, 'player': 'X', 'timestampMs': 8300},
          {'row': 1, 'col': 1, 'player': 'O', 'timestampMs': 8400},
        ],
      });
      expect(nb3.code, 200);

      // 4. leaveRoom from guest during active match -> ALLOW
      final nb4 = await api('rooms/R4E_DART', method: 'PATCH', uid: 'guestE', data: {
        'status': 'abandoned',
        'termination': {
          'reason': 'guestLeft',
          'byUid': 'guestE',
          'byRole': 'guest',
          'message': 'غادر الضيف المباراة، تم إنهاء الجلسة',
          'timestampMs': 8500,
          'atMs': 8500,
        },
        'lastActiveMs': 8500,
      });
      expect(nb4.code, 200);

      // 5. leaveRoom from host in lobby -> ALLOW
      await api('rooms/R4E2_DART', method: 'PUT', uid: 'hostE2', data: {
        'code': 'R4E2_DART',
        'hostUid': 'hostE2',
        'status': 'waitingForGuest',
        'createdAtMs': 9000,
        'lastActiveMs': 9000,
        'config': {'boardSize': 3, 'winStreak': 3, 'roundsToWin': 1},
      });
      final nb5 = await api('rooms/R4E2_DART', method: 'PATCH', uid: 'hostE2', data: {
        'status': 'abandoned',
        'termination': {
          'reason': 'hostLeft',
          'byUid': 'hostE2',
          'byRole': 'host',
          'message': 'تم إنهاء الجلسة من قبل المشرف',
          'timestampMs': 9100,
          'atMs': 9100,
        },
        'lastActiveMs': 9100,
      });
      expect(nb5.code, 200);

      // 6. onDisconnect host simulation -> ALLOW
      await api('rooms/R4E3_DART', method: 'PUT', uid: 'hostE3', data: {
        'code': 'R4E3_DART',
        'hostUid': 'hostE3',
        'status': 'waitingForGuest',
        'createdAtMs': 9500,
        'lastActiveMs': 9500,
        'config': {'boardSize': 3, 'winStreak': 3, 'roundsToWin': 1},
      });
      final nb6 = await api('rooms/R4E3_DART', method: 'PATCH', uid: 'hostE3', data: {
        'status': 'abandoned',
        'termination': {
          'reason': 'hostDisconnected',
          'byUid': 'hostE3',
          'byRole': 'host',
          'message': 'انقطع اتصال المضيف، تم إغلاق الغرفة',
          'timestampMs': 9600,
          'atMs': 9600,
        },
      });
      expect(nb6.code, 200);
    });
  });
}
