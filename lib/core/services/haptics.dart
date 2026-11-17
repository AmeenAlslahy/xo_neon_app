import 'package:flutter/services.dart';

/// Abstract driver interface for haptic sensory feedback.
/// Allows swapping system implementation with a recording mock during automated tests.
abstract interface class HapticsDriver {
  Future<void> selectionClick();
  Future<void> lightImpact();
  Future<void> mediumImpact();
}

/// Standard production driver invoking platform HapticFeedback.
class SystemHapticsDriver implements HapticsDriver {
  const SystemHapticsDriver();

  @override
  Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  @override
  Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  @override
  Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}

/// Mockable recorder driver collecting haptic calls in tests.
class HapticsRecorder implements HapticsDriver {
  final List<String> log = [];

  @override
  Future<void> selectionClick() async {
    log.add('selectionClick');
  }

  @override
  Future<void> lightImpact() async {
    log.add('lightImpact');
  }

  @override
  Future<void> mediumImpact() async {
    log.add('mediumImpact');
  }

  void reset() => log.clear();
  int count(String type) => log.where((e) => e == type).length;
}

/// Central single source of truth for all tactile haptic feedback (UX-DELIGHT-01).
class Haptics {
  Haptics._();

  /// Global toggle for haptics. Default is true.
  static bool enabled = true;

  /// Replaceable driver for unit/widget test environments.
  static HapticsDriver driver = const SystemHapticsDriver();

  /// وضع رمز صحيح — اهتزاز خفيف
  static Future<void> markPlaced() async {
    if (!enabled) return;
    await driver.selectionClick();
  }

  /// لمس زر أساسي — اهتزاز خفيف
  static Future<void> primaryTap() async {
    if (!enabled) return;
    await driver.selectionClick();
  }

  /// نسخ رمز الغرفة — اهتزاز تأكيد
  static Future<void> roomCodeCopied() async {
    if (!enabled) return;
    await driver.lightImpact();
  }

  /// انضمام الضيف في البهو — تنبيه خاطف
  static Future<void> guestJoined() async {
    if (!enabled) return;
    await driver.lightImpact();
  }

  /// حسم جولة — اهتزاز فوز جولة
  static Future<void> roundSettled() async {
    if (!enabled) return;
    await driver.lightImpact();
  }

  /// تعادل — نبضة هادئة
  static Future<void> draw() async {
    if (!enabled) return;
    await driver.selectionClick();
  }

  /// حسم مباراة — اهتزاز تتويج قوي
  static Future<void> matchWon() async {
    if (!enabled) return;
    await driver.mediumImpact();
  }

  /// فشل اتصال — ومضة تنبيه خاطفة مرة واحدة
  static Future<void> connectionFailure() async {
    if (!enabled) return;
    await driver.lightImpact();
  }

  /// Helper for testing to install recorder
  static HapticsRecorder useRecorder() {
    final rec = HapticsRecorder();
    driver = rec;
    return rec;
  }

  /// Reset to standard production driver
  static void useSystemDriver() {
    driver = const SystemHapticsDriver();
    enabled = true;
  }
}
