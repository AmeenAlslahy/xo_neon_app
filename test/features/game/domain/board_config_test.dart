import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/xo_engine.dart';

void main() {
  group('BoardConfig', () {
    test('creates validated custom board configuration successfully', () {
      final config = BoardConfig.validated(rows: 4, cols: 6, winStreak: 4);
      expect(config.rows, equals(4));
      expect(config.cols, equals(6));
      expect(config.winStreak, equals(4));
      expect(config.totalCells, equals(24));
      expect(config.isSquare, isFalse);
    });

    group('Four Authorized Presets Mandated by Game Rules', () {
      test('authorizedPresets contains exactly the 4 authorized configurations', () {
        expect(BoardConfig.authorizedPresets.length, equals(4));
        expect(
          BoardConfig.authorizedPresets,
          containsAllInOrder([
            BoardConfig.grid3x3,
            BoardConfig.grid6x6,
            BoardConfig.grid9x9,
            BoardConfig.grid11x11,
          ]),
        );
      });

      test('3x3 Classic preset: 3 in a row to win', () {
        final config = BoardConfig.grid3x3;
        expect(config.rows, equals(3));
        expect(config.cols, equals(3));
        expect(config.winStreak, equals(3));
        expect(config.totalCells, equals(9));
        expect(config.isSquare, isTrue);
      });

      test('6x6 Tactical preset: 4 in a row to win', () {
        final config = BoardConfig.grid6x6;
        expect(config.rows, equals(6));
        expect(config.cols, equals(6));
        expect(config.winStreak, equals(4));
        expect(config.totalCells, equals(36));
        expect(config.isSquare, isTrue);
      });

      test('9x9 Pro preset: 5 in a row to win', () {
        final config = BoardConfig.grid9x9;
        expect(config.rows, equals(9));
        expect(config.cols, equals(9));
        expect(config.winStreak, equals(5));
        expect(config.totalCells, equals(81));
        expect(config.isSquare, isTrue);
      });

      test('11x11 Master preset: 6 in a row to win', () {
        final config = BoardConfig.grid11x11;
        expect(config.rows, equals(11));
        expect(config.cols, equals(11));
        expect(config.winStreak, equals(6));
        expect(config.totalCells, equals(121));
        expect(config.isSquare, isTrue);
      });
    });

    group('Centralized winStreakForSize and fromSize', () {
      test('winStreakForSize returns exact authorized rules', () {
        expect(BoardConfig.winStreakForSize(3), equals(3));
        expect(BoardConfig.winStreakForSize(6), equals(4));
        expect(BoardConfig.winStreakForSize(9), equals(5));
        expect(BoardConfig.winStreakForSize(11), equals(6));
      });

      test('winStreakForSize throws InvalidBoardConfigException on unauthorized sizes (1, 5, 7, 10)', () {
        expect(() => BoardConfig.winStreakForSize(1), throwsA(isA<InvalidBoardConfigException>()));
        expect(() => BoardConfig.winStreakForSize(5), throwsA(isA<InvalidBoardConfigException>()));
        expect(() => BoardConfig.winStreakForSize(7), throwsA(isA<InvalidBoardConfigException>()));
        expect(() => BoardConfig.winStreakForSize(10), throwsA(isA<InvalidBoardConfigException>()));
      });

      test('fromSize constructs matching authorized configs', () {
        expect(BoardConfig.fromSize(3), equals(BoardConfig.grid3x3));
        expect(BoardConfig.fromSize(6), equals(BoardConfig.grid6x6));
        expect(BoardConfig.fromSize(9), equals(BoardConfig.grid9x9));
        expect(BoardConfig.fromSize(11), equals(BoardConfig.grid11x11));
      });
    });

    group('General Rectangular Grid Support (Engine capability)', () {
      test('supports rectangular dimensions when winStreak <= max(rows, cols)', () {
        final wide = BoardConfig.validated(rows: 3, cols: 5, winStreak: 4);
        expect(wide.rows, equals(3));
        expect(wide.cols, equals(5));
        expect(wide.winStreak, equals(4));
        expect(wide.isSquare, isFalse);

        final tall = BoardConfig.validated(rows: 6, cols: 4, winStreak: 5);
        expect(tall.rows, equals(6));
        expect(tall.cols, equals(4));
        expect(tall.winStreak, equals(5));
        expect(tall.isSquare, isFalse);
      });
    });

    group('Validation & Boundary Enforcement', () {
      test('throws InvalidBoardConfigException when rows < 1', () {
        expect(
          () => BoardConfig.validated(rows: 0, cols: 3, winStreak: 3),
          throwsA(isA<InvalidBoardConfigException>()),
        );
        expect(
          () => BoardConfig.validated(rows: -2, cols: 3, winStreak: 3),
          throwsA(isA<InvalidBoardConfigException>()),
        );
      });

      test('throws InvalidBoardConfigException when cols < 1', () {
        expect(
          () => BoardConfig.validated(rows: 3, cols: 0, winStreak: 3),
          throwsA(isA<InvalidBoardConfigException>()),
        );
        expect(
          () => BoardConfig.validated(rows: 3, cols: -5, winStreak: 3),
          throwsA(isA<InvalidBoardConfigException>()),
        );
      });

      test('throws InvalidBoardConfigException when winStreak < 1', () {
        expect(
          () => BoardConfig.validated(rows: 3, cols: 3, winStreak: 0),
          throwsA(isA<InvalidBoardConfigException>()),
        );
      });

      test('throws InvalidBoardConfigException when winStreak > max(rows, cols)', () {
        expect(
          () => BoardConfig.validated(rows: 3, cols: 3, winStreak: 4),
          throwsA(isA<InvalidBoardConfigException>()),
        );
        expect(
          () => BoardConfig.validated(rows: 4, cols: 2, winStreak: 5),
          throwsA(isA<InvalidBoardConfigException>()),
        );
      });

      test('BUG REPRO: default constructor BoardConfig(...) rejects invalid dimensions and streak at runtime', () {
        expect(() => BoardConfig(rows: 0, cols: 3, winStreak: 3), throwsA(isA<InvalidBoardConfigException>()));
        expect(() => BoardConfig(rows: 3, cols: -1, winStreak: 3), throwsA(isA<InvalidBoardConfigException>()));
        expect(() => BoardConfig(rows: 3, cols: 3, winStreak: 0), throwsA(isA<InvalidBoardConfigException>()));
        expect(() => BoardConfig(rows: 3, cols: 3, winStreak: 4), throwsA(isA<InvalidBoardConfigException>()));
      });
    });

    group('Value Equality & HashCode', () {
      test('instances with identical fields evaluate as equal with same hashCode', () {
        final a = BoardConfig.validated(rows: 6, cols: 6, winStreak: 4);
        final b = BoardConfig.grid6x6;
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });
  });
}
