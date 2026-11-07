/// Monotonic time abstraction for the game domain.
///
/// The domain must never read `DateTime.now()` directly: wall-clock time is
/// user-adjustable and non-monotonic (NTP corrections, manual changes).
/// [TimeSource] exposes a forward-running elapsed duration that is immune to
/// system clock changes.
abstract interface class TimeSource {
  /// Monotonically non-decreasing elapsed time since this source started.
  Duration now();
}

/// Production default: backed by [Stopwatch], which runs on the platform's
/// monotonic performance counter and is unaffected by NTP corrections or
/// manual system-clock changes.
class StopwatchTimeSource implements TimeSource {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  Duration now() => _stopwatch.elapsed;
}

/// Test double: time advances only when the test advances it, making every
/// chess-clock deduction deterministic and scheduling-independent.
class FakeTimeSource implements TimeSource {
  Duration _elapsed = Duration.zero;

  @override
  Duration now() => _elapsed;

  /// Moves the fake clock by [delta]. May be negative ONLY in tests that
  /// simulate clock-rollback anomalies — production sources are monotonic.
  void advance(Duration delta) {
    _elapsed += delta;
  }
}
