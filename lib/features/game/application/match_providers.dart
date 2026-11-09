import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/xo_engine.dart';
import 'difficulty_progression_service.dart';
import 'match_controller.dart';
import 'sound_feedback_service.dart';
import 'system_move_port.dart';

/// Injectable monotonic clock for the whole match layer. Production uses the
/// Stopwatch-based default; tests override with [FakeTimeSource].
final timeSourceProvider = Provider<TimeSource>((ref) => StopwatchTimeSource());

/// Optional injectable [SharedPreferences] instance. Production overrides
/// this at app startup; in unit tests it defaults to null.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Service providing sound effects and haptic feedback.
final soundFeedbackServiceProvider = Provider<SoundFeedbackService>((ref) {
  return SoundFeedbackService(
    isSoundEnabled: () => ref.read(soundEffectsEnabledProvider),
    isHapticsEnabled: () => true,
  );
});

/// Sound effects toggle notifier and provider (persisted in [SharedPreferences]).
class SoundEffectsNotifier extends Notifier<bool> {
  static const _key = 'sound_effects_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getBool(_key) ?? true;
  }

  void toggle() {
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(_key, state);
  }

  void set(bool value) {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(_key, state);
  }
}

final soundEffectsEnabledProvider =
    NotifierProvider<SoundEffectsNotifier, bool>(SoundEffectsNotifier.new);

/// Reduced motion toggle notifier and provider (persisted in [SharedPreferences]).
class ReducedMotionNotifier extends Notifier<bool> {
  static const _key = 'reduced_motion_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getBool(_key) ?? false;
  }

  void toggle() {
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(_key, state);
  }

  void set(bool value) {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(_key, state);
  }
}

final reducedMotionProvider =
    NotifierProvider<ReducedMotionNotifier, bool>(ReducedMotionNotifier.new);

/// Dynamic Difficulty Adjustment (DDA) service managing auto-progression.
final difficultyProgressionServiceProvider =
    Provider<DifficultyProgressionService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DifficultyProgressionService(prefs: prefs);
});

/// Artificial thinking delay for the system move so the AI feels natural
/// and gives visual "thinking" feedback. Defaults to 500ms in production;
/// tests can override with Duration.zero for instant test execution.
final systemThinkingDelayProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 500);
});

/// Injectable system move source. Production runs the P1 selection core on
/// a background isolate; tests override with a controllable scripted port.
final systemMovePortProvider =
    Provider<SystemMovePort>((ref) => const IsolateSystemMovePort());

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
