import 'package:flutter/services.dart';

/// Service providing sound and haptic feedback throughout the match lifecycle.
class SoundFeedbackService {
  final bool Function() isSoundEnabled;
  final bool Function() isHapticsEnabled;

  const SoundFeedbackService({
    required this.isSoundEnabled,
    required this.isHapticsEnabled,
  });

  Future<void> onMovePlaced() async {
    if (isSoundEnabled()) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    if (isHapticsEnabled()) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  Future<void> onSystemMove() async {
    if (isSoundEnabled()) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    if (isHapticsEnabled()) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  Future<void> onRoundWon() async {
    if (isSoundEnabled()) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    if (isHapticsEnabled()) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  Future<void> onRoundLost() async {
    if (isHapticsEnabled()) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  Future<void> onRoundDraw() async {
    if (isHapticsEnabled()) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  Future<void> onButtonClick() async {
    if (isSoundEnabled()) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    if (isHapticsEnabled()) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }
}
