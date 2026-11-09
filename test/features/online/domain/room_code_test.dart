import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/online/domain/models/room_code.dart';

void main() {
  group('RoomCode Domain Value Object', () {
    test('alphabet contains exactly 32 unambiguous characters', () {
      expect(RoomCode.alphabet.length, 32);
      expect(RoomCode.alphabet.contains('0'), isFalse);
      expect(RoomCode.alphabet.contains('O'), isFalse);
      expect(RoomCode.alphabet.contains('1'), isFalse);
      expect(RoomCode.alphabet.contains('I'), isFalse);
    });

    test('validates correct 6-character codes', () {
      expect(RoomCode.isValid('ABCDEF'), isTrue);
      expect(RoomCode.isValid('234567'), isTrue);
      expect(RoomCode.isValid('KLMNPQ'), isTrue);
      expect(RoomCode.isValid('A7K9X2'), isTrue);
    });

    test('rejects codes containing ambiguous or invalid characters', () {
      expect(RoomCode.isValid('ABCD0F'), isFalse); // contains 0
      expect(RoomCode.isValid('ABCDOF'), isFalse); // contains O
      expect(RoomCode.isValid('ABCD1F'), isFalse); // contains 1
      expect(RoomCode.isValid('ABCDIF'), isFalse); // contains I
      expect(RoomCode.isValid('ABC@#%'), isFalse); // special characters
    });

    test('rejects codes of incorrect length', () {
      expect(RoomCode.isValid('ABCDE'), isFalse); // 5 chars
      expect(RoomCode.isValid('ABCDEFG'), isFalse); // 7 chars
      expect(RoomCode.isValid(''), isFalse);
    });

    test('normalizes lowercase input to uppercase and trims', () {
      expect(RoomCode.normalize('  a7k9x2  '), 'A7K9X2');
      final parsed = RoomCode.parse('  a7k9x2  ');
      expect(parsed.value, 'A7K9X2');
    });

    test('parse throws FormatException on invalid input', () {
      expect(() => RoomCode.parse('INVALID_LONG'), throwsFormatException);
      expect(() => RoomCode.parse('ABC012'), throwsFormatException);
    });

    test('tryParse returns null on invalid input', () {
      expect(RoomCode.tryParse(null), isNull);
      expect(RoomCode.tryParse('bad'), isNull);
      expect(RoomCode.tryParse('A7K9X2'), isNotNull);
      expect(RoomCode.tryParse('A7K9X2')!.value, 'A7K9X2');
    });

    test('generate produces 1000 valid codes without ambiguous characters', () {
      final rng = Random(42);
      final set = <String>{};

      for (var i = 0; i < 1000; i++) {
        final code = RoomCode.generate(rng);
        expect(code.value.length, 6);
        expect(RoomCode.isValid(code.value), isTrue);
        expect(code.value.contains(RegExp('[01OI]')), isFalse);
        set.add(code.value);
      }

      // Check high collision resistance with Random
      expect(set.length, greaterThan(990));
    });

    test('equality and hashCode work as value object', () {
      final code1 = RoomCode.parse('A7K9X2');
      final code2 = RoomCode.parse('a7k9x2');
      final code3 = RoomCode.parse('B7K9X2');

      expect(code1, equals(code2));
      expect(code1.hashCode, equals(code2.hashCode));
      expect(code1, isNot(equals(code3)));
      expect(code1.toString(), 'A7K9X2');
    });
  });
}
