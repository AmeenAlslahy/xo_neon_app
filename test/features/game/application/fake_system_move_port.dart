import 'dart:async';

import 'package:xo_neon_app/features/game/application/system_move_port.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

/// Controllable [SystemMovePort] for tests: scripted immediate moves, gated
/// futures for race scenarios, or a default first-empty-cell policy — no
/// real isolates and no real waits.
class FakeSystemMovePort implements SystemMovePort {
  final List<Object> _script = [];
  int _calls = 0;

  /// Board snapshots as received by [selectMove], in call order.
  final List<GameState> receivedStates = [];

  /// Queues an immediate scripted move for the next request.
  void enqueueImmediate(Position move) => _script.add(move);

  /// Queues a manually completed gate for the next request (race tests).
  void enqueueGate(Completer<Position?> completer) => _script.add(completer);

  /// Queues an error for the next request (port failure / unsupported platform tests).
  void enqueueError(Object error) => _script.add(error);

  int get callCount => _calls;

  @override
  Future<Position?> selectMove(GameState state, SystemDifficulty difficulty) {
    _calls++;
    receivedStates.add(state);
    final entry = _script.isEmpty ? null : _script.removeAt(0);
    if (entry is Completer<Position?>) {
      return entry.future;
    }
    if (entry is Position) {
      return Future.value(entry);
    }
    if (entry is Object) {
      return Future.error(entry);
    }
    return Future.value(_firstEmptyCell(state));
  }

  /// Always-legal fallback policy: the first empty cell in scan order.
  static Position firstEmptyCell(GameState state) {
    for (var r = 0; r < state.board.config.rows; r++) {
      for (var c = 0; c < state.board.config.cols; c++) {
        final p = Position(r, c);
        if (state.board.isEmpty(p)) {
          return p;
        }
      }
    }
    return const Position(0, 0);
  }

  Position _firstEmptyCell(GameState state) => firstEmptyCell(state);
}

/// Minimal state-driven port for widget tests: always plays the first empty
/// cell (legal on any non-full board).
class FirstEmptySystemMovePort implements SystemMovePort {
  const FirstEmptySystemMovePort();

  @override
  Future<Position?> selectMove(GameState state, SystemDifficulty difficulty) {
    for (var r = 0; r < state.board.config.rows; r++) {
      for (var c = 0; c < state.board.config.cols; c++) {
        final p = Position(r, c);
        if (state.board.isEmpty(p)) {
          return Future.value(p);
        }
      }
    }
    return Future.value(null);
  }
}
