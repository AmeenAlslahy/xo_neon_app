import 'dart:math';
import 'dart:typed_data';

import '../logic/game_board.dart';
import '../logic/win_evaluator.dart';
import '../models/board_config.dart';
import '../models/cell_position.dart';
import '../models/game_state.dart';
import '../models/player.dart';

const WinEvaluator _evaluator = WinEvaluator();

/// Difficulty of the system player's move selection.
///
/// 5 levels, from weakest to strongest. Auto-progression promotes one level
/// after every human win (see DifficultyProgressionService). There is no
/// demotion: the level the player reached is the level they keep until they
/// win again.
enum SystemDifficulty { easy, medium, hard, expert, master }

/// Pure, Flutter-free move-selection core for the system player.
///
/// Contract:
/// - Reads a [GameState] snapshot and returns a candidate [Position], or null
///   when the game is over, the board is full, or no valid cell can be chosen.
///   A null return is a normal outcome — callers must not assume a move always
///   exists.
/// - Never mutates state: simulations use [GameBoard.copyWithMove] on copies.
/// - Never bypasses the engine: applying the returned cell (turn, occupancy,
///   win detection, chess-clock acceptance) remains [MatchEngine]'s
///   responsibility. Win logic is reused through [WinEvaluator], never
///   reimplemented.
///
/// Strength limits of the [SystemDifficulty.hard] selector: alpha-beta search
/// with iterative deepening, a pruned candidate set, a threat-aware leaf
/// evaluation (win-window weights for both sides: open lines scored by mark
/// count, blocked windows dead, K−1 windows as one-move threats whose sum
/// signals double threats; center as a small secondary helper), and a node
/// cap on boards larger than 3×3 with last-completed-depth retention.
/// On 3×3 the node cap does not apply (the full tree is bounded), the search
/// is exhaustive, and its optimality is verified exhaustively against an
/// independent minimax reference by
/// system_move_selector_optimality_test.dart. On larger boards the search is
/// depth-limited and deliberately beatable: iterative deepening keeps the
/// last fully completed depth, and only when even the first depth is truncated
/// does the capped root scan decide (documented limitation).
/// [SearchMoveSelector.selectMoveAsync] performs the same search but yields
/// between root branches so a web build can keep painting; it chooses the
/// same move as [selectMove].
/// Ties in scores resolve deterministically (best center weight, then scan
/// order).
abstract class SystemMoveSelector {
  const SystemMoveSelector();

  /// Chooses a cell for [state.currentPlayer], or null when no move exists.
  Position? selectMove(GameState state);

  /// Async variant used by application ports that cannot use an isolate
  /// (Flutter Web). The default preserves the synchronous behavior; the hard
  /// selector may yield between root branches so the event loop can paint
  /// between search chunks instead of freezing for the whole search.
  Future<Position?> selectMoveAsync(GameState state) async => selectMove(state);

  /// Builds the selector for [difficulty]. [random] is injected randomness
  /// used by the easy level (and ignored by the deterministic levels);
  /// omitting it uses a platform-seeded [Random].
  static SystemMoveSelector forDifficulty(
    SystemDifficulty difficulty, {
    Random? random,
  }) {
    switch (difficulty) {
      case SystemDifficulty.easy:
        return RandomMoveSelector(random: random);
      case SystemDifficulty.medium:
        return HeuristicMoveSelector();
      case SystemDifficulty.hard:
        return SearchMoveSelector(difficultyTier: 0);
      case SystemDifficulty.expert:
        return SearchMoveSelector(difficultyTier: 1);
      case SystemDifficulty.master:
        return SearchMoveSelector(difficultyTier: 2);
    }
  }
}

/// All in-bounds empty cells in deterministic row-major scan order.
List<Position> _emptyCells(GameState state) {
  final board = state.board;
  final cells = <Position>[];
  for (var r = 0; r < board.config.rows; r++) {
    for (var c = 0; c < board.config.cols; c++) {
      final p = Position(r, c);
      if (board.isEmpty(p)) {
        cells.add(p);
      }
    }
  }
  return cells;
}

/// True when no selection is possible at all: a terminal game or a full board.
bool _selectionUnavailable(GameState state) =>
    state.isGameOver || state.board.isFull;

/// Scans every empty cell for an immediate win for [player].
/// Cost: O(empty cells) win-checks on simulated boards.
Position? _findImmediateMove(GameBoard board, Player player) {
  for (var r = 0; r < board.config.rows; r++) {
    for (var c = 0; c < board.config.cols; c++) {
      final p = Position(r, c);
      if (!board.isEmpty(p)) {
        continue;
      }
      final simulated = board.copyWithMove(p, player);
      if (_evaluator.checkWinFromMove(
            board: simulated,
            lastMove: p,
            player: player,
          ) !=
          null) {
        return p;
      }
    }
  }
  return null;
}

/// Detects open threat patterns for [opponent] (_ P P _, P _ P, _ P P P _)
/// across all 4 directions and returns the best blocking cell, or null if none.
Position? _findOpenThreatBlock(GameBoard board, Player opponent) {
  if (board.config.winStreak < 4) {
    return null;
  }
  final config = board.config;
  final k = config.winStreak;
  final candidates = <Position, int>{};

  const directions = [
    (0, 1),   // horizontal →
    (1, 0),   // vertical ↓
    (1, 1),   // diagonal ↘
    (1, -1),  // diagonal ↙
  ];

  for (var r = 0; r < config.rows; r++) {
    for (var c = 0; c < config.cols; c++) {
      final p = Position(r, c);
      if (board.cellAt(p) != opponent) {
        continue;
      }

      for (final (dr, dc) in directions) {
        // --- 1. Open Three: _ P P P _ (when k >= 5) ---
        if (k >= 5) {
          final p1 = Position(r + dr, c + dc);
          final p2 = Position(r + 2 * dr, c + 2 * dc);
          if (board.isWithinBounds(p1) &&
              board.cellAt(p1) == opponent &&
              board.isWithinBounds(p2) &&
              board.cellAt(p2) == opponent) {
            final before = Position(r - dr, c - dc);
            final after = Position(r + 3 * dr, c + 3 * dc);
            final beforeOpen =
                board.isWithinBounds(before) && board.isEmpty(before);
            final afterOpen =
                board.isWithinBounds(after) && board.isEmpty(after);
            if (beforeOpen && afterOpen) {
              candidates[before] = max(candidates[before] ?? 0, 3000);
              candidates[after] = max(candidates[after] ?? 0, 3000);
            }
          }
        }

        // --- 2. Open Two: _ P P _ (two consecutive with both ends open) ---
        final p1 = Position(r + dr, c + dc);
        if (board.isWithinBounds(p1) && board.cellAt(p1) == opponent) {
          final before = Position(r - dr, c - dc);
          final after = Position(r + 2 * dr, c + 2 * dc);
          final beforeOpen =
              board.isWithinBounds(before) && board.isEmpty(before);
          final afterOpen =
              board.isWithinBounds(after) && board.isEmpty(after);
          if (beforeOpen && afterOpen) {
            candidates[before] = max(candidates[before] ?? 0, 2000);
            candidates[after] = max(candidates[after] ?? 0, 2000);
          }
        }

        // --- 3. Split Two: P _ P (separated by 1 empty cell) ---
        final mid = Position(r + dr, c + dc);
        final p2 = Position(r + 2 * dr, c + 2 * dc);
        if (board.isWithinBounds(mid) &&
            board.isEmpty(mid) &&
            board.isWithinBounds(p2) &&
            board.cellAt(p2) == opponent) {
          final before = Position(r - dr, c - dc);
          final after = Position(r + 3 * dr, c + 3 * dc);
          final beforeOpen =
              board.isWithinBounds(before) && board.isEmpty(before);
          final afterOpen =
              board.isWithinBounds(after) && board.isEmpty(after);
          if (beforeOpen || afterOpen) {
            candidates[mid] = max(candidates[mid] ?? 0, 1500);
          }
        }
      }
    }
  }

  if (candidates.isEmpty) {
    return null;
  }

  var bestEntry = candidates.entries.first;
  var bestScore = _centerScore(config, bestEntry.key);

  for (final entry in candidates.entries.skip(1)) {
    if (entry.value > bestEntry.value) {
      bestEntry = entry;
      bestScore = _centerScore(config, entry.key);
    } else if (entry.value == bestEntry.value) {
      final score = _centerScore(config, entry.key);
      if (score > bestScore) {
        bestEntry = entry;
        bestScore = score;
      } else if (score == bestScore) {
        if (entry.key.row < bestEntry.key.row ||
            (entry.key.row == bestEntry.key.row &&
                entry.key.col < bestEntry.key.col)) {
          bestEntry = entry;
          bestScore = score;
        }
      }
    }
  }

  return bestEntry.key;
}

/// Finds an offensive open-threat move for [me] to extend into an open three
/// or three-in-a-row.
Position? _findOpenThreatMove(GameBoard board, Player me) {
  if (board.config.winStreak < 4) {
    return null;
  }
  final config = board.config;
  final candidates = <Position, int>{};

  const directions = [
    (0, 1),
    (1, 0),
    (1, 1),
    (1, -1),
  ];

  for (var r = 0; r < config.rows; r++) {
    for (var c = 0; c < config.cols; c++) {
      final p = Position(r, c);
      if (board.cellAt(p) != me) {
        continue;
      }

      for (final (dr, dc) in directions) {
        final p1 = Position(r + dr, c + dc);
        if (board.isWithinBounds(p1) && board.cellAt(p1) == me) {
          final before = Position(r - dr, c - dc);
          final after = Position(r + 2 * dr, c + 2 * dc);
          if (board.isWithinBounds(before) && board.isEmpty(before)) {
            candidates[before] = max(candidates[before] ?? 0, 1000);
          }
          if (board.isWithinBounds(after) && board.isEmpty(after)) {
            candidates[after] = max(candidates[after] ?? 0, 1000);
          }
        }

        final mid = Position(r + dr, c + dc);
        final p2 = Position(r + 2 * dr, c + 2 * dc);
        if (board.isWithinBounds(mid) &&
            board.isEmpty(mid) &&
            board.isWithinBounds(p2) &&
            board.cellAt(p2) == me) {
          candidates[mid] = max(candidates[mid] ?? 0, 1200);
        }
      }
    }
  }

  if (candidates.isEmpty) {
    return null;
  }

  var bestEntry = candidates.entries.first;
  var bestScore = _centerScore(config, bestEntry.key);

  for (final entry in candidates.entries.skip(1)) {
    if (entry.value > bestEntry.value) {
      bestEntry = entry;
      bestScore = _centerScore(config, entry.key);
    } else if (entry.value == bestEntry.value) {
      final score = _centerScore(config, entry.key);
      if (score > bestScore) {
        bestEntry = entry;
        bestScore = score;
      }
    }
  }

  return bestEntry.key;
}

/// Integer center-weight of a cell (larger = more central). Doubled
/// coordinates keep everything in exact integer arithmetic, so ties compare
/// reliably even for boards with no single center cell (6×6, 11×11...).
int _centerScore(BoardConfig config, Position p) {
  final dr = 2 * p.row - (config.rows - 1);
  final dc = 2 * p.col - (config.cols - 1);
  final maxDr = config.rows - 1;
  final maxDc = config.cols - 1;
  final maxDistSq = maxDr * maxDr + maxDc * maxDc;
  final distSq = dr * dr + dc * dc;
  return maxDistSq - distSq;
}

/// Easy: a uniformly random valid cell. Randomness is injectable for
/// deterministic tests ([Random(seed)] or a scripted fake).
class RandomMoveSelector extends SystemMoveSelector {
  RandomMoveSelector({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  Position? selectMove(GameState state) {
    if (_selectionUnavailable(state)) {
      return null;
    }
    final cells = _emptyCells(state);
    if (cells.isEmpty) {
      return null;
    }
    return cells[_random.nextInt(cells.length)];
  }
}

/// Medium: immediate win, then immediate block, then open threat defense (85%),
/// then offensive threat creation, then deterministic center fallback.
class HeuristicMoveSelector extends SystemMoveSelector {
  const HeuristicMoveSelector({this.random});

  final Random? random;
  static final Random _defaultRandom = Random();

  @override
  Position? selectMove(GameState state) {
    if (_selectionUnavailable(state)) {
      return null;
    }
    final me = state.currentPlayer;
    final board = state.board;

    final win = _findImmediateMove(board, me);
    if (win != null) {
      return win;
    }
    final block = _findImmediateMove(board, me.other);
    if (block != null) {
      return block;
    }

    final openThreat = _findOpenThreatBlock(board, me.other);
    if (openThreat != null) {
      final rng = random ?? _defaultRandom;
      if (rng.nextDouble() < 0.85) {
        return openThreat;
      }
    }

    final ownThreat = _findOpenThreatMove(board, me);
    if (ownThreat != null) {
      return ownThreat;
    }

    // Center-weighted fallback, deterministic on ties.
    final cells = _emptyCells(state);
    if (cells.isEmpty) {
      return null;
    }
    var best = cells.first;
    var bestScore = _centerScore(board.config, best);
    for (final cell in cells.skip(1)) {
      final score = _centerScore(board.config, cell);
      if (score > bestScore) {
        best = cell;
        bestScore = score;
      }
    }
    return best;
  }
}

/// Hard: alpha-beta search with a per-size depth budget and a pruned
/// candidate set. Immediate wins and direct blocks are scanned across ALL
/// valid cells first (before any pruning). Fully deterministic.
///
/// Depth budget: 3×3 searches the full tree — the node cap does NOT apply
/// there (the tree is bounded at ≈550k nodes worst case), so play on 3×3 is
/// exhaustive and its optimality is proven by the exhaustive reference test.
/// 6×6 gets depth 3; 9×9 and 11×11 get depth 2, bounded by [maxNodes]. The
/// root loop always examines every root move; if the cap is exhausted during
/// a depth iteration, that iteration's mixed partial/static result is
/// discarded and the last completed depth's move is kept. Only a truncation
/// at depth 1 (no completed depth to fall back to) leaves the capped scan to
/// decide. Proven wins and losses always dominate.
/// See the class-level strength limits on [SystemMoveSelector].
class SearchMoveSelector extends SystemMoveSelector {
  SearchMoveSelector({
    this.maxNodes = defaultMaxNodes,
    this.timeBudgetMs = defaultTimeBudgetMs,
    this.difficultyTier = 0,
  });

  final int maxNodes;
  final int timeBudgetMs;

  /// 0 = hard, 1 = expert, 2 = master.
  /// Adds +1/+2 plies to the depth budget and scales time budget accordingly.
  final int difficultyTier;

  static const int defaultMaxNodes = 500000;
  static const int defaultTimeBudgetMs = 800;
  static const int _winBase = 1 << 20;

  int _nodes = 0;
  int _activeNodeCap = defaultMaxNodes;
  Stopwatch? _timeStopwatch;
  int _lastCompletedDepth = 0;

  /// Returns the deepest completed depth iteration reached in the most recent search.
  int get lastCompletedDepth => _lastCompletedDepth;

  /// Returns the configured target depth for [config] at this selector's difficulty tier.
  int targetDepth(BoardConfig config) => _depthFor(config);

  /// Effective search time budget scaled by difficulty tier.
  /// Base 800ms + 200ms per tier for expert (1000ms) / master (1200ms) to
  /// reach deeper target search depths on larger boards.
  int get effectiveTimeBudgetMs => timeBudgetMs + (difficultyTier * 200);

  bool get _isBudgetExhausted =>
      _nodes >= _activeNodeCap ||
      (_timeStopwatch != null &&
          _timeStopwatch!.elapsedMilliseconds >= effectiveTimeBudgetMs);

  /// Per-config geometry (win windows, neighbor lists, center weights),
  /// computed once per selector instance. All hot-path loops use flat cell
  /// indices into [GameBoard.cells] to avoid Position allocation per node.
  final Map<BoardConfig, _BoardGeometry> _geometryCache = {};

  _BoardGeometry _geometryFor(BoardConfig config) => _geometryCache.putIfAbsent(
        config,
        () => _BoardGeometry(config),
      );

  @override
  Position? selectMove(GameState state) {
    if (_selectionUnavailable(state)) {
      return null;
    }
    final me = state.currentPlayer;
    final board = state.board;
    final config = board.config;

    // Policy: immediate win and direct block across ALL valid cells first.
    final policy = _immediatePolicyMove(board, me);
    if (policy != null) {
      return policy;
    }

    final candidates = _prunedMoves(board);
    if (candidates.isEmpty) {
      return null;
    }

    _nodes = 0;
    _lastCompletedDepth = 0;
    _timeStopwatch = Stopwatch()..start();
    _activeNodeCap = config.totalCells <= 9 ? 1 << 60 : maxNodes;
    if (config.totalCells <= 9) {
      // 3×3: single exhaustive full-depth search (proven optimal by the
      // independent reference sweep).
      _lastCompletedDepth = config.totalCells;
      return _searchRoot(board, candidates, me, config.totalCells - 1).$1;
    }

    // 1. Check immediate fork creation or fork block before minimax search:
    final forkMove = _findForkMove(board, candidates, me);
    if (forkMove != null) {
      return forkMove;
    }

    // 2. Victory by Continuous Fours (VCF) up to depth 6 on large boards:
    final vcfMove = _findVCF(board, me, 6);
    if (vcfMove != null) {
      return vcfMove;
    }

    // Larger boards: iterative deepening up to the depth budget. Each
    // COMPLETED depth yields an exact-by-depth result which is retained;
    // if the node or time budget is exhausted mid-depth, the LAST COMPLETED depth's
    // move is returned (the truncated iteration's guess is discarded —
    // its children are a mix of deeper searches and static leaves, so its
    // ranking is not trustworthy). When even depth 1 is truncated (e.g.
    // maxNodes=1), there is no completed depth to fall back to, so the
    // truncated scan itself is kept instead of an arbitrary first candidate.
    var bestCell = candidates.first;
    var completedAnyDepth = false;
    for (var depth = 1; depth <= _depthFor(config); depth++) {
      if (completedAnyDepth && _isBudgetExhausted) {
        break;
      }
      final result = _searchRoot(board, candidates, me, depth - 1);
      if (!completedAnyDepth) {
        bestCell = result.$1;
      }
      if (result.$2) {
        break; // budget exhausted: keep the last completed depth's move
      }
      bestCell = result.$1;
      completedAnyDepth = true;
      _lastCompletedDepth = depth;
    }
    return bestCell;
  }

  /// Cooperative variant for the Web port: same policy, same iterative
  /// deepening, same last-completed-depth retention as [selectMove], but the
  /// root scan yields to the event loop after roughly [_yieldBudgetMs] of work
  /// so the UI can paint between search chunks. 3×3 stays synchronous (its
  /// full tree is cheap and must stay a single exhaustive search).
  @override
  Future<Position?> selectMoveAsync(GameState state) async {
    if (_selectionUnavailable(state)) {
      return null;
    }
    final me = state.currentPlayer;
    final board = state.board;
    final config = board.config;

    final policy = _immediatePolicyMove(board, me);
    if (policy != null) {
      return policy;
    }

    final candidates = _prunedMoves(board);
    if (candidates.isEmpty) {
      return null;
    }

    _nodes = 0;
    _lastCompletedDepth = 0;
    _timeStopwatch = Stopwatch()..start();
    _activeNodeCap = config.totalCells <= 9 ? 1 << 60 : maxNodes;
    if (config.totalCells <= 9) {
      return _searchRoot(board, candidates, me, config.totalCells - 1).$1;
    }

    // 1. Check immediate fork creation or fork block before minimax search:
    final forkMove = _findForkMove(board, candidates, me);
    if (forkMove != null) {
      return forkMove;
    }

    // 2. Victory by Continuous Fours (VCF) up to depth 6 on large boards:
    final vcfMove = _findVCF(board, me, 6);
    if (vcfMove != null) {
      return vcfMove;
    }

    var bestCell = candidates.first;
    var completedAnyDepth = false;
    for (var depth = 1; depth <= _depthFor(config); depth++) {
      if (completedAnyDepth && _isBudgetExhausted) {
        break;
      }
      final result =
          await _searchRootAsync(board, candidates, me, depth - 1);
      if (!completedAnyDepth) {
        bestCell = result.$1;
      }
      if (result.$2) {
        break;
      }
      bestCell = result.$1;
      completedAnyDepth = true;
      _lastCompletedDepth = depth;
    }
    return bestCell;
  }

  /// Immediate-win / immediate-block policy shared by the sync and async
  /// entry points. Returns null when the search must decide.
  Position? _immediatePolicyMove(GameBoard board, Player me) {
    final win = _findImmediateMove(board, me);
    if (win != null) {
      return win;
    }
    return _findImmediateMove(board, me.other);
  }

  /// Checks for an immediate fork creation (for [me]) or fork block (for [me.other]).
  Position? _findForkMove(
    GameBoard board,
    List<Position> candidates,
    Player me,
  ) {
    final geometry = _geometryFor(board.config);
    final context = _SearchContext.fromBoard(board, geometry);

    // 1. Can [me] create an immediate winning fork?
    Position? bestForkMove;
    var bestForkCenter = -1;
    for (final move in candidates) {
      context.makeMove(move, me);
      final hasFork = context.threatWindowCountFor(me) >= 2 &&
          context.distinctWinningThreats(me) >= 2;
      context.undoMove(move, me);
      if (hasFork) {
        final center = _centerScore(board.config, move);
        if (center > bestForkCenter) {
          bestForkCenter = center;
          bestForkMove = move;
        }
      }
    }
    if (bestForkMove != null) {
      return bestForkMove;
    }

    // 2. Will [opponent] create an immediate winning fork on their next turn?
    final opponent = me.other;
    Position? bestBlockMove;
    var bestBlockCenter = -1;
    for (final move in candidates) {
      context.makeMove(move, opponent);
      final hasFork = context.threatWindowCountFor(opponent) >= 2 &&
          context.distinctWinningThreats(opponent) >= 2;
      context.undoMove(move, opponent);
      if (hasFork) {
        final center = _centerScore(board.config, move);
        if (center > bestBlockCenter) {
          bestBlockCenter = center;
          bestBlockMove = move;
        }
      }
    }
    if (bestBlockMove != null) {
      return bestBlockMove;
    }

    return null;
  }

  /// Searches for a Victory by Continuous Fours (VCF) forced winning sequence
  /// up to [depth] plies ahead. At each step, [player] plays a move creating a
  /// direct win threat; the opponent has only 1 forced blocking response.
  Position? _findVCF(GameBoard board, Player player, int depth) {
    if (board.config.winStreak < 4 || depth <= 0) {
      return null;
    }
    final candidates = _prunedMoves(board);
    for (final move in candidates) {
      board.copyWithMoveInPlace(move, player);
      final isWin = _evaluator.checkWinFromMove(
            board: board,
            lastMove: move,
            player: player,
          ) !=
          null;
      if (isWin) {
        board.undo(move);
        return move;
      }

      final threats = _findAllImmediateWins(board, player);
      if (threats.length >= 2) {
        board.undo(move);
        return move;
      }

      if (threats.length == 1 && depth >= 2) {
        final block = threats.first;
        board.copyWithMoveInPlace(block, player.other);
        final oppWin = _evaluator.checkWinFromMove(
              board: board,
              lastMove: block,
              player: player.other,
            ) !=
            null;
        if (!oppWin) {
          final next = _findVCF(board, player, depth - 2);
          board.undo(block);
          board.undo(move);
          if (next != null) {
            return move;
          }
        } else {
          board.undo(block);
          board.undo(move);
        }
      } else {
        board.undo(move);
      }
    }
    return null;
  }

  List<Position> _findAllImmediateWins(GameBoard board, Player player) {
    final wins = <Position>[];
    for (var r = 0; r < board.config.rows; r++) {
      for (var c = 0; c < board.config.cols; c++) {
        final p = Position(r, c);
        if (!board.isEmpty(p)) {
          continue;
        }
        if (_evaluator.checkWinFromMove(
              board: board,
              lastMove: p,
              player: player,
            ) !=
            null) {
          wins.add(p);
        }
      }
    }
    return wins;
  }

  /// Event-loop yield budget for [selectMoveAsync]. One root child can
  /// overshoot this by its own subtree cost; the budget only decides when to
  /// yield, not how deep a child searches.
  static const int _yieldBudgetMs = 8;

  int _depthFor(BoardConfig config) {
    final cells = config.totalCells;
    if (cells <= 9) {
      return cells; // 3×3: full tree
    }
    final base = cells <= 36 ? 5 : (cells <= 81 ? 4 : 3);
    return base + difficultyTier;
  }

  /// One root selection at the given child depth: full window per child
  /// (exact values), best-first ordering, center tie-break. Returns the
  /// chosen move and whether the node budget ran out mid-selection.
  (Position, bool) _searchRoot(
    GameBoard board,
    List<Position> candidates,
    Player me,
    int childDepth,
  ) {
    final config = board.config;
    var bestCell = candidates.first;
    var bestScore = -_winBase * 4;
    var bestCenter = -1;
    var truncated = false;
    for (final (cell, score) in _rootChildScores(
      board,
      candidates,
      me,
      childDepth,
    )) {
      final center = _centerScore(config, cell);
      if (score > bestScore || (score == bestScore && center > bestCenter)) {
        bestScore = score;
        bestCell = cell;
        bestCenter = center;
      }
      if (_isBudgetExhausted) {
        // Mark the iteration as truncated but keep scanning the remaining
        // root moves: their subtrees collapse to the static evaluation, so the
        // scan is cheap, and the center tie-break stays a deterministic
        // fallback when no depth completed (maxNodes tiny).
        truncated = true;
      }
    }
    return (bestCell, truncated);
  }

  /// Async twin of [_searchRoot] for [selectMoveAsync]: identical scoring and
  /// truncation semantics, but control returns to the event loop once the
  /// current chunk has used [_yieldBudgetMs]. Yielding never changes the
  /// search tree, node count, or move choice.
  Future<(Position, bool)> _searchRootAsync(
    GameBoard board,
    List<Position> candidates,
    Player me,
    int childDepth,
  ) async {
    final config = board.config;
    var bestCell = candidates.first;
    var bestScore = -_winBase * 4;
    var bestCenter = -1;
    var truncated = false;
    final chunk = Stopwatch()..start();
    for (final (cell, score) in _rootChildScores(
      board,
      candidates,
      me,
      childDepth,
    )) {
      final center = _centerScore(config, cell);
      if (score > bestScore || (score == bestScore && center > bestCenter)) {
        bestScore = score;
        bestCell = cell;
        bestCenter = center;
      }
      if (_isBudgetExhausted) {
        truncated = true;
      }
      if (chunk.elapsedMilliseconds >= _yieldBudgetMs) {
        await Future<void>.delayed(Duration.zero);
        chunk.reset();
      }
    }
    return (bestCell, truncated);
  }

  /// Lazily yields one scored root child at a time. Callers own the
  /// best-score/center bookkeeping, so the sync and async root loops share the
  /// exact same search work.
  Iterable<(Position, int)> _rootChildScores(
    GameBoard board,
    List<Position> candidates,
    Player me,
    int childDepth,
  ) sync* {
    final geometry = _geometryFor(board.config);
    final ordered = _orderMoves(board, candidates, me);
    final context = _SearchContext.fromBoard(board, geometry);
    for (final cell in ordered) {
      context.makeMove(cell, me);
      final score = _search(
        context: context,
        lastMove: cell,
        mover: me,
        me: me,
        depth: childDepth,
        ply: 1,
        alpha: -_winBase * 4,
        beta: _winBase * 4,
      );
      context.undoMove(cell, me);
      yield (cell, score);
    }
  }

  /// Best-first move ordering: children probed by their positional eval
  /// (line threats + center) so alpha-beta cutoffs fire earlier.
  List<Position> _orderMoves(
    GameBoard board,
    List<Position> moves,
    Player turn,
  ) {
    final geometry = _geometryFor(board.config);
    final context = _SearchContext.fromBoard(board, geometry);
    final scored = <(Position, int)>[];
    for (final move in moves) {
      context.makeMove(move, turn);
      scored.add((move, context.evalFor(turn)));
      context.undoMove(move, turn);
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final entry in scored) entry.$1];
  }

  /// Pruned move set for the search: 3×3 expands everything; larger boards
  /// expand empty neighbors (Chebyshev distance 1) of occupied cells, with a
  /// central opening move on an empty board.
  List<Position> _prunedMoves(GameBoard board) {
    final config = board.config;
    final raw = board.rawCells;
    Position toPosition(int index) =>
        Position(index ~/ config.cols, index % config.cols);

    if (config.totalCells <= 9) {
      return [
        for (var i = 0; i < raw.length; i++)
          if (raw[i] == 0) toPosition(i),
      ];
    }

    final geometry = _geometryFor(config);
    final candidateIndices = <int>{};
    var occupied = 0;
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] == 0) {
        continue;
      }
      occupied++;
      for (final neighbor in geometry.neighbors[i]) {
        if (raw[neighbor] == 0) {
          candidateIndices.add(neighbor);
        }
      }
    }
    if (occupied == 0) {
      return [Position(config.rows ~/ 2, config.cols ~/ 2)];
    }

    // Opening development: after one or two stones, a purely local candidate
    // set cannot even consider the central band. Keep the tactical neighbors
    // but add the central cells so the search can contest the opening instead
    // of being forced into the corner neighborhood. This is deliberately
    // limited to the opening: adding the center as a decoy later would
    // outvote genuine line threats (see the large-board tests).
    if (occupied <= 2) {
      final bandSize = config.rows <= 6 ? 2 : 3;
      final startRow = (config.rows - bandSize) ~/ 2;
      final startCol = (config.cols - bandSize) ~/ 2;
      for (var r = startRow; r < startRow + bandSize; r++) {
        for (var c = startCol; c < startCol + bandSize; c++) {
          final index = r * config.cols + c;
          if (raw[index] == 0) {
            candidateIndices.add(index);
          }
        }
      }
    }

    if (candidateIndices.isEmpty) {
      return [
        for (var i = 0; i < raw.length; i++)
          if (raw[i] == 0) toPosition(i),
      ];
    }
    return [for (final index in candidateIndices) toPosition(index)]
      ..sort((a, b) {
        final byRow = a.row.compareTo(b.row);
        return byRow != 0 ? byRow : a.col.compareTo(b.col);
      });
  }

  /// Negamax-style alpha-beta step with in-place incremental evaluation.
  int _search({
    required _SearchContext context,
    required Position lastMove,
    required Player mover,
    required Player me,
    required int depth,
    required int ply,
    required int alpha,
    required int beta,
  }) {
    _nodes++;
    final board = context.board;
    // Terminal: the move just played ended the game. A win reached through
    // fewer plies from the root scores higher.
    if (_evaluator.checkWinFromMove(
          board: board,
          lastMove: lastMove,
          player: mover,
        ) !=
        null) {
      return mover == me ? _winBase - ply : -(_winBase - ply);
    }
    if (board.isFull) {
      return 0;
    }
    if (_isBudgetExhausted) {
      return context.evalFor(me);
    }

    final turn = mover.other;
    if (depth <= 0) {
      // Quiescence at the horizon: if the side to move can win immediately,
      // play that forced move instead of handing the position to the static
      // evaluator.
      if (board.config.totalCells > 9) {
        final win = context.immediateWin(turn);
        if (win != null) {
          context.makeMove(win, turn);
          final score = _search(
            context: context,
            lastMove: win,
            mover: turn,
            me: me,
            depth: 0,
            ply: ply + 1,
            alpha: alpha,
            beta: beta,
          );
          context.undoMove(win, turn);
          return score;
        }
      }
      return context.evalFor(me);
    }

    final moves = _prunedMoves(board);
    if (moves.isEmpty) {
      return context.evalFor(me);
    }

    if (turn == me) {
      var best = -_winBase * 4;
      var a = alpha;
      for (final move in moves) {
        context.makeMove(move, turn);
        final score = _search(
          context: context,
          lastMove: move,
          mover: turn,
          me: me,
          depth: depth - 1,
          ply: ply + 1,
          alpha: a,
          beta: beta,
        );
        context.undoMove(move, turn);
        best = max(best, score);
        a = max(a, best);
        if (beta <= a) {
          break;
        }
      }
      return best;
    } else {
      var best = _winBase * 4;
      var b = beta;
      for (final move in moves) {
        context.makeMove(move, turn);
        final score = _search(
          context: context,
          lastMove: move,
          mover: turn,
          me: me,
          depth: depth - 1,
          ply: ply + 1,
          alpha: alpha,
          beta: b,
        );
        context.undoMove(move, turn);
        best = min(best, score);
        b = min(b, best);
        if (b <= alpha) {
          break;
        }
      }
      return best;
    }
  }

  /// Threat-aware positional leaf evaluation for standalone inspection and testing.
  int evaluateBoard(GameBoard board, Player me) {
    final geometry = _geometryFor(board.config);
    return _SearchContext.fromBoard(board, geometry).evalFor(me);
  }

  static int _lineWeight(int count) => count <= 0 ? 0 : 1 << (2 * (count - 1));
}

/// Precomputed per-config lookup tables shared by every search node.
///
/// Everything is stored as flat indices into [GameBoard.cells]; the search
/// never allocates a [Position] merely to read a cell. Rows, columns, and both
/// diagonal families are deduplicated via run-start detection.
class _BoardGeometry {
  _BoardGeometry._({
    required this.config,
    required this.centers,
    required this.windows,
    required this.neighbors,
    required this.windowsByCell,
  });

  factory _BoardGeometry(BoardConfig config) {
    final centers = List<int>.generate(
      config.totalCells,
      (index) => _centerScore(
        config,
        Position(index ~/ config.cols, index % config.cols),
      ),
      growable: false,
    );
    final windows = _buildWindows(config);
    final neighbors = _buildNeighbors(config);
    final windowsByCell = _buildWindowsByCell(config.totalCells, windows);
    return _BoardGeometry._(
      config: config,
      centers: centers,
      windows: windows,
      neighbors: neighbors,
      windowsByCell: windowsByCell,
    );
  }

  final BoardConfig config;
  final List<int> centers;
  final List<List<int>> windows;
  final List<List<int>> neighbors;
  final List<List<int>> windowsByCell;

  static List<List<int>> _buildWindows(BoardConfig config) {
    final k = config.winStreak;
    final windows = <List<int>>[];
    void collect(int dr, int dc) {
      for (var r = 0; r < config.rows; r++) {
        for (var c = 0; c < config.cols; c++) {
          final backR = r - dr;
          final backC = c - dc;
          final isRunStart = backR < 0 ||
              backR >= config.rows ||
              backC < 0 ||
              backC >= config.cols;
          if (!isRunStart) {
            continue;
          }
          var len = 0;
          var rr = r;
          var cc = c;
          while (rr >= 0 && rr < config.rows && cc >= 0 && cc < config.cols) {
            len++;
            rr += dr;
            cc += dc;
          }
          for (var s = 0; s + k <= len; s++) {
            windows.add(List<int>.unmodifiable([
              for (var i = 0; i < k; i++)
                (r + (s + i) * dr) * config.cols + c + (s + i) * dc,
            ]));
          }
        }
      }
    }

    collect(0, 1); // rows
    collect(1, 0); // columns
    collect(1, 1); // diagonal ↘
    collect(1, -1); // diagonal ↙
    return List.unmodifiable(windows);
  }

  static List<List<int>> _buildNeighbors(BoardConfig config) {
    return List.unmodifiable([
      for (var r = 0; r < config.rows; r++)
        for (var c = 0; c < config.cols; c++)
          List<int>.unmodifiable([
            for (var dr = -1; dr <= 1; dr++)
              for (var dc = -1; dc <= 1; dc++)
                if ((dr != 0 || dc != 0) &&
                    r + dr >= 0 &&
                    r + dr < config.rows &&
                    c + dc >= 0 &&
                    c + dc < config.cols)
                  (r + dr) * config.cols + c + dc,
          ]),
    ]);
  }

  static List<List<int>> _buildWindowsByCell(
    int totalCells,
    List<List<int>> windows,
  ) {
    final byCell = List.generate(totalCells, (_) => <int>[]);
    for (var wId = 0; wId < windows.length; wId++) {
      for (final cellIndex in windows[wId]) {
        byCell[cellIndex].add(wId);
      }
    }
    return List.unmodifiable(byCell.map((l) => List<int>.unmodifiable(l)));
  }
}

/// Incremental search context tracking board state, window occupancies, and
/// live positional scores (scoreX, scoreO) without allocating at each tree node.
class _SearchContext {
  final GameBoard board;
  final _BoardGeometry geometry;
  final Uint8List windowCountX;
  final Uint8List windowCountO;

  int totalWindowScoreX = 0;
  int totalWindowScoreO = 0;
  int centerScoreX = 0;
  int centerScoreO = 0;
  int threatWindowCountX = 0;
  int threatWindowCountO = 0;

  int threatWindowCountFor(Player p) =>
      p == Player.x ? threatWindowCountX : threatWindowCountO;

  _SearchContext._({
    required this.board,
    required this.geometry,
    required this.windowCountX,
    required this.windowCountO,
  });

  factory _SearchContext.fromBoard(GameBoard board, _BoardGeometry geometry) {
    final ctx = _SearchContext._(
      board: board,
      geometry: geometry,
      windowCountX: Uint8List(geometry.windows.length),
      windowCountO: Uint8List(geometry.windows.length),
    );
    ctx._initialize();
    return ctx;
  }

  void _initialize() {
    final cells = board.rawCells;
    for (var i = 0; i < cells.length; i++) {
      final v = cells[i];
      if (v == 1) {
        centerScoreX += geometry.centers[i] ~/ 8;
      } else if (v == 2) {
        centerScoreO += geometry.centers[i] ~/ 8;
      }
    }

    final k = geometry.config.winStreak;
    for (var wId = 0; wId < geometry.windows.length; wId++) {
      var x = 0;
      var o = 0;
      for (final cellIndex in geometry.windows[wId]) {
        final v = cells[cellIndex];
        if (v == 1) {
          x++;
        } else if (v == 2) {
          o++;
        }
      }
      windowCountX[wId] = x;
      windowCountO[wId] = o;
      if (x > 0 && o == 0) {
        totalWindowScoreX += SearchMoveSelector._lineWeight(x);
        if (x == k - 1) {
          threatWindowCountX++;
        }
      } else if (o > 0 && x == 0) {
        totalWindowScoreO += SearchMoveSelector._lineWeight(o);
        if (o == k - 1) {
          threatWindowCountO++;
        }
      }
    }
  }

  /// Applies a move in-place and incrementally updates window counts and scores.
  void makeMove(Position position, Player player) {
    board.copyWithMoveInPlace(position, player);
    final cellIndex = position.row * board.config.cols + position.col;
    _applyDelta(cellIndex, player);
  }

  void _applyDelta(int cellIndex, Player player) {
    final centerDelta = geometry.centers[cellIndex] ~/ 8;
    final isX = player == Player.x;
    final k = geometry.config.winStreak;

    if (isX) {
      centerScoreX += centerDelta;
    } else {
      centerScoreO += centerDelta;
    }

    for (final wId in geometry.windowsByCell[cellIndex]) {
      final oldX = windowCountX[wId];
      final oldO = windowCountO[wId];

      if (isX) {
        if (oldX > 0 && oldO == 0) {
          totalWindowScoreX -= SearchMoveSelector._lineWeight(oldX);
          if (oldX == k - 1) {
            threatWindowCountX--;
          }
        } else if (oldO > 0 && oldX == 0) {
          totalWindowScoreO -= SearchMoveSelector._lineWeight(oldO);
          if (oldO == k - 1) {
            threatWindowCountO--;
          }
        }
        final newX = oldX + 1;
        windowCountX[wId] = newX;
        if (newX > 0 && oldO == 0) {
          totalWindowScoreX += SearchMoveSelector._lineWeight(newX);
          if (newX == k - 1) {
            threatWindowCountX++;
          }
        }
      } else {
        if (oldO > 0 && oldX == 0) {
          totalWindowScoreO -= SearchMoveSelector._lineWeight(oldO);
          if (oldO == k - 1) {
            threatWindowCountO--;
          }
        } else if (oldX > 0 && oldO == 0) {
          totalWindowScoreX -= SearchMoveSelector._lineWeight(oldX);
          if (oldX == k - 1) {
            threatWindowCountX--;
          }
        }
        final newO = oldO + 1;
        windowCountO[wId] = newO;
        if (newO > 0 && oldX == 0) {
          totalWindowScoreO += SearchMoveSelector._lineWeight(newO);
          if (newO == k - 1) {
            threatWindowCountO++;
          }
        }
      }
    }
  }

  /// Reverses an in-place move and restores window counts and scores.
  void undoMove(Position position, Player player) {
    board.undo(position);
    final cellIndex = position.row * board.config.cols + position.col;
    _revertDelta(cellIndex, player);
  }

  void _revertDelta(int cellIndex, Player player) {
    final centerDelta = geometry.centers[cellIndex] ~/ 8;
    final isX = player == Player.x;
    final k = geometry.config.winStreak;

    if (isX) {
      centerScoreX -= centerDelta;
    } else {
      centerScoreO -= centerDelta;
    }

    for (final wId in geometry.windowsByCell[cellIndex]) {
      final curX = windowCountX[wId];
      final curO = windowCountO[wId];

      if (isX) {
        if (curX > 0 && curO == 0) {
          totalWindowScoreX -= SearchMoveSelector._lineWeight(curX);
          if (curX == k - 1) {
            threatWindowCountX--;
          }
        }
        final prevX = curX - 1;
        windowCountX[wId] = prevX;
        if (prevX > 0 && curO == 0) {
          totalWindowScoreX += SearchMoveSelector._lineWeight(prevX);
          if (prevX == k - 1) {
            threatWindowCountX++;
          }
        } else if (prevX == 0 && curO > 0) {
          totalWindowScoreO += SearchMoveSelector._lineWeight(curO);
          if (curO == k - 1) {
            threatWindowCountO++;
          }
        }
      } else {
        if (curO > 0 && curX == 0) {
          totalWindowScoreO -= SearchMoveSelector._lineWeight(curO);
          if (curO == k - 1) {
            threatWindowCountO--;
          }
        }
        final prevO = curO - 1;
        windowCountO[wId] = prevO;
        if (prevO > 0 && curX == 0) {
          totalWindowScoreO += SearchMoveSelector._lineWeight(prevO);
          if (prevO == k - 1) {
            threatWindowCountO++;
          }
        } else if (prevO == 0 && curX > 0) {
          totalWindowScoreX += SearchMoveSelector._lineWeight(curX);
          if (curX == k - 1) {
            threatWindowCountX++;
          }
        }
      }
    }
  }

  /// Counts distinct winning threat cells for [player]. Returns 2 as soon
  /// as at least two distinct winning cells are detected.
  int distinctWinningThreats(Player player) {
    final k = board.config.winStreak;
    final isX = player == Player.x;
    final ownCounts = isX ? windowCountX : windowCountO;
    final oppCounts = isX ? windowCountO : windowCountX;

    final winningCells = <int>{};
    for (var wId = 0; wId < geometry.windows.length; wId++) {
      if (ownCounts[wId] == k - 1 && oppCounts[wId] == 0) {
        for (final cellIndex in geometry.windows[wId]) {
          if (board.rawCellAtIndex(cellIndex) == 0) {
            winningCells.add(cellIndex);
            break;
          }
        }
        if (winningCells.length >= 2) {
          return 2;
        }
      }
    }
    return winningCells.length;
  }

  /// O(1) evaluation score from perspective of [me], with fork bonus.
  int evalFor(Player me) {
    var scoreX = totalWindowScoreX + centerScoreX;
    var scoreO = totalWindowScoreO + centerScoreO;
    if (threatWindowCountX >= 2 && distinctWinningThreats(Player.x) >= 2) {
      scoreX += 5000;
    }
    if (threatWindowCountO >= 2 && distinctWinningThreats(Player.o) >= 2) {
      scoreO += 5000;
    }
    return me == Player.x ? (scoreX - scoreO) : (scoreO - scoreX);
  }

  /// Fast immediate win detection directly from window counts.
  Position? immediateWin(Player player) {
    final k = board.config.winStreak;
    final isX = player == Player.x;
    final ownCounts = isX ? windowCountX : windowCountO;
    final oppCounts = isX ? windowCountO : windowCountX;

    for (var wId = 0; wId < geometry.windows.length; wId++) {
      if (ownCounts[wId] == k - 1 && oppCounts[wId] == 0) {
        for (final cellIndex in geometry.windows[wId]) {
          if (board.rawCellAtIndex(cellIndex) == 0) {
            return Position(
              cellIndex ~/ board.config.cols,
              cellIndex % board.config.cols,
            );
          }
        }
      }
    }
    return null;
  }
}
