/// Presets and configuration for the chess-clock style match timer.
enum TimerPreset {
  none,
  oneMinute,
  threeMinutes,
  fiveMinutes,
  custom,
}

class TimerConfig {
  final bool enabled;
  final Duration durationPerPlayer;
  final TimerPreset preset;

  const TimerConfig({
    required this.enabled,
    required this.durationPerPlayer,
    this.preset = TimerPreset.none,
  });

  const TimerConfig.disabled()
      : enabled = false,
        durationPerPlayer = Duration.zero,
        preset = TimerPreset.none;

  factory TimerConfig.fromPreset(TimerPreset preset, {Duration? customDuration}) {
    switch (preset) {
      case TimerPreset.none:
        return const TimerConfig.disabled();
      case TimerPreset.oneMinute:
        return const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(minutes: 1),
          preset: TimerPreset.oneMinute,
        );
      case TimerPreset.threeMinutes:
        return const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(minutes: 3),
          preset: TimerPreset.threeMinutes,
        );
      case TimerPreset.fiveMinutes:
        return const TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(minutes: 5),
          preset: TimerPreset.fiveMinutes,
        );
      case TimerPreset.custom:
        final duration = customDuration ?? const Duration(minutes: 2);
        // Reasonable input bounds: min 15 seconds, max 15 minutes (900 seconds)
        final clampedSeconds = duration.inSeconds.clamp(15, 15 * 60);
        return TimerConfig(
          enabled: true,
          durationPerPlayer: Duration(seconds: clampedSeconds),
          preset: TimerPreset.custom,
        );
    }
  }

  TimerConfig copyWith({
    bool? enabled,
    Duration? durationPerPlayer,
    TimerPreset? preset,
  }) {
    return TimerConfig(
      enabled: enabled ?? this.enabled,
      durationPerPlayer: durationPerPlayer ?? this.durationPerPlayer,
      preset: preset ?? this.preset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerConfig &&
          other.enabled == enabled &&
          other.durationPerPlayer == durationPerPlayer &&
          other.preset == preset;

  @override
  int get hashCode => Object.hash(enabled, durationPerPlayer, preset);

  @override
  String toString() =>
      'TimerConfig(enabled: $enabled, duration: ${durationPerPlayer.inSeconds}s, preset: $preset)';
}
