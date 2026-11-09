import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../domain/ai/system_move_selector.dart';
import '../domain/models/cell_position.dart';
import '../domain/models/game_state.dart';

/// Produces the system player's move for a game-state snapshot.
///
/// Contract:
/// - Pure with respect to [state]: implementations must not mutate it.
/// - May execute on a background isolate (production native) or time-sliced on
///   the event loop (web); the caller re-validates identity/phase/turn/board/time
///   before applying the returned cell through the match engine, so stale or
///   invalid results are always rejected.
/// - Returning null means "no move available" (terminal/full board) — the
///   caller keeps the engine state as the source of truth.
abstract class SystemMovePort {
  Future<Position?> selectMove(GameState state, SystemDifficulty difficulty);
}

/// Production port: runs the P1 selection core on a background isolate on native
/// platforms so the hard level's search can never block the UI thread.
/// On Flutter Web (where dart:isolate is unsupported and throws UnsupportedError),
/// runs the hard search on the main event loop but time-sliced: the selector
/// yields between root branches so frames can render between chunks. A plain
/// Future() alone would still block for the whole search.
class IsolateSystemMovePort implements SystemMovePort {
  const IsolateSystemMovePort();

  @override
  Future<Position?> selectMove(GameState state, SystemDifficulty difficulty) {
    if (kIsWeb) {
      final selector = SystemMoveSelector.forDifficulty(difficulty);
      // The hard selector's async path yields between root branches so the
      // browser event loop can paint while the search runs. A Future() alone
      // does NOT move the search off the main thread.
      return selector.selectMoveAsync(state);
    }
    return Isolate.run(() {
      final selector = SystemMoveSelector.forDifficulty(difficulty);
      return selector.selectMove(state);
    });
  }
}
