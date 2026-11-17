import 'package:flutter/services.dart';
import '../../../../core/services/haptics.dart';

/// Service providing sound and haptic feedback throughout the match lifecycle.
/// Updated for UX-DELIGHT-01: Routes all tactile feedback through central Haptics service.
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
      await Haptics.markPlaced();
    }
  }

  Future<void> onSystemMove() async {
    if (isSoundEnabled()) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    // No haptics for system moves
  }

  Future<void> onRoundWon() async {
    if (isSoundEnabled()) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    if (isHapticsEnabled()) {
      await Haptics.roundSettled();
    }
  }

  Future<void> onRoundLost() async {
    // Per UX-DELIGHT-01 table: "خلية غير متاحة / خصم يفوز: لا شيء"
  }

  Future<void> onRoundDraw() async {
    if (isHapticsEnabled()) {
      await Haptics.draw();
    }
  }

  Future<void> onButtonClick() async {
    if (isSoundEnabled()) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    if (isHapticsEnabled()) {
      await Haptics.primaryTap();
    }
  }
}
