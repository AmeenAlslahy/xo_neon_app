import 'dart:math';

/// Domain value object representing a 6-character, human-friendly room code.
///
/// Uses an unambiguous alphabet excluding characters that easily confuse
/// human players on phone screens (`0`, `O`, `1`, `I`).
class RoomCode {
  RoomCode._(this.value);

  /// 32-character unambiguous alphabet.
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int codeLength = 6;

  /// The uppercase 6-character code string.
  final String value;

  /// Factory constructor that validates and normalizes the given code string.
  /// Throws [FormatException] if the code is invalid.
  factory RoomCode.parse(String raw) {
    final normalized = normalize(raw);
    if (!isValid(normalized)) {
      throw FormatException(
        'Invalid room code "$raw". Must be 6 characters from alphabet: $alphabet',
      );
    }
    return RoomCode._(normalized);
  }

  /// Tries to parse [raw] code, returning null if invalid.
  static RoomCode? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = normalize(raw);
    if (!isValid(normalized)) return null;
    return RoomCode._(normalized);
  }

  /// Generates a cryptographically-secure random 6-character room code.
  factory RoomCode.generate([Random? random]) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < codeLength; i++) {
      final index = rng.nextInt(alphabet.length);
      buffer.write(alphabet[index]);
    }
    return RoomCode._(buffer.toString());
  }

  /// Normalizes raw input: trims whitespace and converts to uppercase.
  static String normalize(String raw) {
    return raw.trim().toUpperCase();
  }

  /// Checks whether [raw] code matches the valid length and allowed alphabet.
  static bool isValid(String raw) {
    final cleaned = normalize(raw);
    if (cleaned.length != codeLength) return false;
    for (var i = 0; i < cleaned.length; i++) {
      if (!alphabet.contains(cleaned[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomCode && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
