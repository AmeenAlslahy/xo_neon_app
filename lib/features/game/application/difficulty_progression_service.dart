import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/xo_engine.dart';

enum ProgressionChange {
  none,
  promoted,
}

class ProgressionRecord {
  final SystemDifficulty previousDifficulty;
  final SystemDifficulty newDifficulty;
  final ProgressionChange change;
  final int streak;

  const ProgressionRecord({
    required this.previousDifficulty,
    required this.newDifficulty,
    required this.change,
    required this.streak,
  });

  bool get hasChanged => change != ProgressionChange.none;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressionRecord &&
          other.previousDifficulty == previousDifficulty &&
          other.newDifficulty == newDifficulty &&
          other.change == change &&
          other.streak == streak;

  @override
  int get hashCode => Object.hash(
        previousDifficulty,
        newDifficulty,
        change,
        streak,
      );
}

class DifficultyProgressionState {
  final SystemDifficulty currentDifficulty;
  final int consecutiveWins;
  final int consecutiveLosses;
  final int totalWins;
  final int totalLosses;
  final int totalDraws;
  final bool isAutoProgressionEnabled;
  final ProgressionRecord? lastRecord;

  const DifficultyProgressionState({
    this.currentDifficulty = SystemDifficulty.easy,
    this.consecutiveWins = 0,
    this.consecutiveLosses = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalDraws = 0,
    this.isAutoProgressionEnabled = true,
    this.lastRecord,
  });

  double get winRate {
    final total = totalWins + totalLosses + totalDraws;
    if (total == 0) return 0.0;
    return totalWins / total;
  }

  DifficultyProgressionState copyWith({
    SystemDifficulty? currentDifficulty,
    int? consecutiveWins,
    int? consecutiveLosses,
    int? totalWins,
    int? totalLosses,
    int? totalDraws,
    bool? isAutoProgressionEnabled,
    ProgressionRecord? lastRecord,
  }) {
    return DifficultyProgressionState(
      currentDifficulty: currentDifficulty ?? this.currentDifficulty,
      consecutiveWins: consecutiveWins ?? this.consecutiveWins,
      consecutiveLosses: consecutiveLosses ?? this.consecutiveLosses,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
      totalDraws: totalDraws ?? this.totalDraws,
      isAutoProgressionEnabled:
          isAutoProgressionEnabled ?? this.isAutoProgressionEnabled,
      lastRecord: lastRecord ?? this.lastRecord,
    );
  }
}

/// Service managing Dynamic Difficulty Adjustment (DDA) for vs-system matches.
///
/// Rules:
/// - After EVERY human win against the system → auto-promote exactly one
///   level (easy → medium → hard → expert → master).
/// - On human loss → NO demotion. The level the player reached is preserved.
///   This avoids the frustrating "I just lost, why is the AI also easier now"
///   feeling and keeps momentum forward.
/// - On draw → streaks preserved, level unchanged.
/// - When already at [SystemDifficulty.master], further wins keep it there.
/// - All state persisted in [SharedPreferences].
class DifficultyProgressionService {
  static const String keyDifficulty = 'difficulty_progression_level';
  static const String keyWins = 'difficulty_progression_streak_wins';
  static const String keyLosses = 'difficulty_progression_streak_losses';
  static const String keyTotalWins = 'difficulty_progression_total_wins';
  static const String keyTotalLosses = 'difficulty_progression_total_losses';
  static const String keyTotalDraws = 'difficulty_progression_total_draws';
  static const String keyAutoEnabled = 'difficulty_progression_auto_enabled';

  final SharedPreferences? _prefs;
  DifficultyProgressionState _state;

  DifficultyProgressionState get state => _state;

  DifficultyProgressionService({
    SharedPreferences? prefs,
    DifficultyProgressionState? initialState,
  })  : _prefs = prefs,
        _state = initialState ??
            (prefs != null
                ? _loadFromPrefs(prefs)
                : const DifficultyProgressionState());

  static DifficultyProgressionState _loadFromPrefs(SharedPreferences prefs) {
    final diffName = prefs.getString(keyDifficulty);
    SystemDifficulty difficulty = SystemDifficulty.easy;
    if (diffName != null) {
      for (final d in SystemDifficulty.values) {
        if (d.name == diffName) {
          difficulty = d;
          break;
        }
      }
    }

    return DifficultyProgressionState(
      currentDifficulty: difficulty,
      consecutiveWins: prefs.getInt(keyWins) ?? 0,
      consecutiveLosses: prefs.getInt(keyLosses) ?? 0,
      totalWins: prefs.getInt(keyTotalWins) ?? 0,
      totalLosses: prefs.getInt(keyTotalLosses) ?? 0,
      totalDraws: prefs.getInt(keyTotalDraws) ?? 0,
      isAutoProgressionEnabled: prefs.getBool(keyAutoEnabled) ?? true,
    );
  }

  /// Sets manual difficulty, resetting active win/loss streaks.
  void setDifficulty(SystemDifficulty difficulty) {
    _state = _state.copyWith(
      currentDifficulty: difficulty,
      consecutiveWins: 0,
      consecutiveLosses: 0,
      lastRecord: ProgressionRecord(
        previousDifficulty: _state.currentDifficulty,
        newDifficulty: difficulty,
        change: ProgressionChange.none,
        streak: 0,
      ),
    );
    _saveToPrefs();
  }

  void setAutoProgressionEnabled(bool enabled) {
    _state = _state.copyWith(isAutoProgressionEnabled: enabled);
    _saveToPrefs();
  }

  /// Returns the difficulty one level above [current], or null at the top.
  static SystemDifficulty? nextDifficulty(SystemDifficulty current) {
    final idx = SystemDifficulty.values.indexOf(current);
    if (idx < 0 || idx >= SystemDifficulty.values.length - 1) {
      return null;
    }
    return SystemDifficulty.values[idx + 1];
  }

  /// Records the outcome of a completed match against the system.
  ///
  /// [humanWon]: true if the human won, false if the system won,
  /// null for a draw.
  ///
  /// Promotion fires on EVERY human win (not after N consecutive wins).
  /// Demotion is never applied — loss preserves the current level.
  ProgressionRecord recordMatchOutcome({required bool? humanWon}) {
    final prevDiff = _state.currentDifficulty;
    var nextDiff = prevDiff;
    var change = ProgressionChange.none;
    int nextWins = _state.consecutiveWins;
    int nextLosses = _state.consecutiveLosses;
    int totalWins = _state.totalWins;
    int totalLosses = _state.totalLosses;
    int totalDraws = _state.totalDraws;

    if (humanWon == true) {
      totalWins++;
      nextWins++;
      nextLosses = 0;

      if (_state.isAutoProgressionEnabled) {
        final promoted = nextDifficulty(prevDiff);
        if (promoted != null) {
          nextDiff = promoted;
          change = ProgressionChange.promoted;
        }
        // Already at master → stay at master, no change.
      }
    } else if (humanWon == false) {
      totalLosses++;
      nextLosses++;
      nextWins = 0;
      // NO demotion. Level preserved on loss.
    } else {
      // Draw: preserve streaks, level unchanged.
      totalDraws++;
    }

    final record = ProgressionRecord(
      previousDifficulty: prevDiff,
      newDifficulty: nextDiff,
      change: change,
      streak: humanWon == true
          ? nextWins
          : humanWon == false
              ? nextLosses
              : 0,
    );

    _state = _state.copyWith(
      currentDifficulty: nextDiff,
      consecutiveWins: nextWins,
      consecutiveLosses: nextLosses,
      totalWins: totalWins,
      totalLosses: totalLosses,
      totalDraws: totalDraws,
      lastRecord: record,
    );

    _saveToPrefs();
    return record;
  }

  void resetStats() {
    _state = const DifficultyProgressionState();
    _saveToPrefs();
  }

  void _saveToPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(prefs.setString(keyDifficulty, _state.currentDifficulty.name));
    unawaited(prefs.setInt(keyWins, _state.consecutiveWins));
    unawaited(prefs.setInt(keyLosses, _state.consecutiveLosses));
    unawaited(prefs.setInt(keyTotalWins, _state.totalWins));
    unawaited(prefs.setInt(keyTotalLosses, _state.totalLosses));
    unawaited(prefs.setInt(keyTotalDraws, _state.totalDraws));
    unawaited(prefs.setBool(keyAutoEnabled, _state.isAutoProgressionEnabled));
  }
}
