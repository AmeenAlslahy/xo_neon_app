import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/xo_engine.dart';
import 'match_controller.dart';

/// Injectable monotonic clock for the whole match layer. Production uses the
/// Stopwatch-based default; tests override with [FakeTimeSource].
final timeSourceProvider = Provider<TimeSource>((ref) => StopwatchTimeSource());

/// Grid/rounds/timer configuration chosen in the setup screen for the NEXT
/// match. Kept alive so a selection survives until the board consumes it.
final pendingMatchConfigProvider =
    NotifierProvider<PendingMatchConfig, MatchConfig?>(PendingMatchConfig.new);

class PendingMatchConfig extends Notifier<MatchConfig?> {
  @override
  MatchConfig? build() {
    ref.keepAlive();
    return null;
  }

  void select(MatchConfig config) => state = config;
}

/// Resolved configuration consumed by [matchControllerProvider]. Tests
/// override this directly with [ProviderContainer] / [ProviderScope].
///
/// The fallback deliberately reuses [MatchConfig]'s own constructor defaults —
/// the single source of truth for the approved policy: 3 rounds, chess clock
/// off.
final matchConfigProvider = Provider<MatchConfig>((ref) {
  return ref.watch(pendingMatchConfigProvider) ??
      const MatchConfig(boardConfig: BoardConfig.grid3x3);
});

/// The match controller: the only component allowed to schedule timers
/// against a match (chess-clock ticker, round transitions, finalize delay).
///
/// `autoDispose` is deliberate: Riverpod's plain [NotifierProvider] is
/// keep-alive by default, which would keep the chess-clock ticker and
/// transition timers running after the board screen unmounts.
final matchControllerProvider =
    NotifierProvider.autoDispose<MatchController, MatchUiState>(
  MatchController.new,
);
