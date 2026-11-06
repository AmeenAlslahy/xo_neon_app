import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../domain/xo_engine.dart';

/// Non-obscuring banner presented between rounds showing the round outcome,
/// updated score, and a 3-second auto-transition countdown with a quick skip option.
class RoundEndBanner extends StatefulWidget {
  final MatchState matchState;
  final VoidCallback onNextRound;
  final AppStrings strings;
  final bool reduceMotion;

  const RoundEndBanner({
    super.key,
    required this.matchState,
    required this.onNextRound,
    this.strings = const AppStrings(),
    this.reduceMotion = false,
  });

  @override
  State<RoundEndBanner> createState() => _RoundEndBannerState();
}

class _RoundEndBannerState extends State<RoundEndBanner> {
  int _secondsRemaining = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    if (widget.reduceMotion) {
      // In reduced motion, 2 seconds for comfortable reading
      _secondsRemaining = 2;
    } else {
      _secondsRemaining = 3;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        timer.cancel();
        widget.onNextRound();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.matchState;
    final strings = widget.strings;
    final isWon = state.roundEndReason == RoundEndReason.win;
    final isTimeout = state.roundEndReason == RoundEndReason.timeout;

    final Color themeColor;
    final String headline;
    final IconData icon;

    if (isTimeout) {
      themeColor = state.roundWinner == Player.x ? NeonColors.cyanX : NeonColors.orangeO;
      headline = strings.timeoutMessage(state.roundWinner!.other.symbol);
      icon = Icons.timer_off_outlined;
    } else if (isWon) {
      themeColor = state.roundWinner == Player.x ? NeonColors.cyanX : NeonColors.orangeO;
      headline = strings.winnerWon(state.roundWinner!.symbol);
      icon = Icons.emoji_events_rounded;
    } else {
      themeColor = NeonColors.amberGold;
      headline = strings.roundDrawMessage;
      icon = Icons.handshake_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF120B28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: themeColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.nextRoundIn(_secondsRemaining > 0 ? _secondsRemaining : 1),
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: themeColor.withValues(alpha: 0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: themeColor.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: () {
              _countdownTimer?.cancel();
              widget.onNextRound();
            },
            child: Text(
              strings.nextRoundNow,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
