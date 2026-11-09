import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xo_neon_app/features/game/application/difficulty_progression_service.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DifficultyProgressionService service;

  setUp(() {
    service = DifficultyProgressionService(); // in-memory, no prefs
  });

  group('Auto-progression — promotion rules', () {
    test('starts at easy by default', () {
      expect(service.state.currentDifficulty, SystemDifficulty.easy);
    });

    test('EVERY win promotes exactly one level (not after 2)', () {
      // Win 1 → easy → medium
      var record = service.recordMatchOutcome(humanWon: true);
      expect(record.change, ProgressionChange.promoted);
      expect(service.state.currentDifficulty, SystemDifficulty.medium);

      // Win 2 → medium → hard
      record = service.recordMatchOutcome(humanWon: true);
      expect(service.state.currentDifficulty, SystemDifficulty.hard);

      // Win 3 → hard → expert
      record = service.recordMatchOutcome(humanWon: true);
      expect(service.state.currentDifficulty, SystemDifficulty.expert);

      // Win 4 → expert → master
      record = service.recordMatchOutcome(humanWon: true);
      expect(service.state.currentDifficulty, SystemDifficulty.master);
    });

    test('at master, further wins keep master (no overflow)', () {
      service.setDifficulty(SystemDifficulty.master);
      final record = service.recordMatchOutcome(humanWon: true);
      expect(record.change, ProgressionChange.none);
      expect(service.state.currentDifficulty, SystemDifficulty.master);
    });

    test('promotion does not occur when auto-progression is disabled', () {
      service.setAutoProgressionEnabled(false);
      service.recordMatchOutcome(humanWon: true);
      expect(service.state.currentDifficulty, SystemDifficulty.easy);
    });
  });

  group('Auto-progression — loss rules (no demotion)', () {
    test('loss never demotes, even from master', () {
      service.setDifficulty(SystemDifficulty.master);
      service.recordMatchOutcome(humanWon: false);
      expect(service.state.currentDifficulty, SystemDifficulty.master);

      service.recordMatchOutcome(humanWon: false);
      expect(service.state.currentDifficulty, SystemDifficulty.master);
    });

    test('loss never demotes from hard', () {
      service.setDifficulty(SystemDifficulty.hard);
      service.recordMatchOutcome(humanWon: false);
      service.recordMatchOutcome(humanWon: false);
      expect(service.state.currentDifficulty, SystemDifficulty.hard);
    });

    test('loss after promotion keeps the promoted level', () {
      // easy → medium
      service.recordMatchOutcome(humanWon: true);
      expect(service.state.currentDifficulty, SystemDifficulty.medium);

      // Lose → stays medium
      service.recordMatchOutcome(humanWon: false);
      expect(service.state.currentDifficulty, SystemDifficulty.medium);
    });
  });

  group('Auto-progression — draw rules', () {
    test('draw does not change level or streaks', () {
      service.setDifficulty(SystemDifficulty.medium);
      final record = service.recordMatchOutcome(humanWon: null);
      expect(record.change, ProgressionChange.none);
      expect(service.state.currentDifficulty, SystemDifficulty.medium);
    });
  });

  group('Win rate & stats', () {
    test('win rate computed correctly', () {
      service.recordMatchOutcome(humanWon: true);   // 1 win
      service.recordMatchOutcome(humanWon: false);  // 1 loss
      service.recordMatchOutcome(humanWon: null);   // 1 draw
      expect(service.state.winRate, closeTo(1 / 3, 0.001));
    });
  });

  group('nextDifficulty helper', () {
    test('walks through all 5 levels', () {
      expect(
        DifficultyProgressionService.nextDifficulty(SystemDifficulty.easy),
        SystemDifficulty.medium,
      );
      expect(
        DifficultyProgressionService.nextDifficulty(SystemDifficulty.medium),
        SystemDifficulty.hard,
      );
      expect(
        DifficultyProgressionService.nextDifficulty(SystemDifficulty.hard),
        SystemDifficulty.expert,
      );
      expect(
        DifficultyProgressionService.nextDifficulty(SystemDifficulty.expert),
        SystemDifficulty.master,
      );
      expect(
        DifficultyProgressionService.nextDifficulty(SystemDifficulty.master),
        isNull,
      );
    });
  });

  group('Manual difficulty & persistence', () {
    test('setDifficulty resets both win and loss streaks', () {
      service.recordMatchOutcome(humanWon: true); // win streak = 1
      service.recordMatchOutcome(humanWon: true); // win streak = 2
      expect(service.state.consecutiveWins, 2);

      service.setDifficulty(SystemDifficulty.hard);

      expect(service.state.consecutiveWins, 0);
      expect(service.state.consecutiveLosses, 0);
      expect(service.state.currentDifficulty, SystemDifficulty.hard);
    });

    test('persistence round-trip via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final persisted = DifficultyProgressionService(prefs: prefs);

      persisted.setDifficulty(SystemDifficulty.expert);
      persisted.recordMatchOutcome(humanWon: true); // expert → master

      // Simulate app restart
      final reloaded = DifficultyProgressionService(prefs: prefs);
      expect(reloaded.state.currentDifficulty, SystemDifficulty.master);
      expect(reloaded.state.totalWins, 1);
    });
  });
}
