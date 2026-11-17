import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/xo_engine.dart';
import 'celebration_glyphs.dart';

/// Passive banner presented between non-final rounds showing the round outcome,
/// the updated score, and the controller-owned auto-transition countdown (UX-DELIGHT-01).
/// Uses vector celebration glyphs (Trophy for win, Interlocking X/O for draw, text only for loss).
class RoundEndBanner extends ConsumerWidget {
  final MatchState matchState;
  final int transitionSecondsRemaining;
  final VoidCallback onNextRound;

  const RoundEndBanner({
    super.key,
    required this.matchState,
    this.transitionSecondsRemaining = 3,
    required this.onNextRound,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = matchState;
    final strings = ref.watch(stringsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final isWon = state.roundEndReason == RoundEndReason.win;
    final isTimeout = state.roundEndReason == RoundEndReason.timeout;
    final isHumanWinner = state.roundWinner == state.config.humanPlayer;

    final Color themeColor;
    final String headline;
    final Widget? glyph;

    if (isTimeout) {
      themeColor = AppTokens.amberGold;
      headline = strings.timeoutMessage(state.roundWinner!.other.symbol);
      glyph = const Icon(Icons.timer_off_outlined, color: AppTokens.amberGold, size: 24);
    } else if (isWon) {
      if (state.config.vsSystem) {
        if (isHumanWinner) {
          themeColor = AppTokens.amberGold;
          headline = isArabic ? 'جولة لك!' : 'Round Won!';
          glyph = const TrophyGlyphWidget(size: 28);
        } else {
          themeColor = AppTokens.borderSubtle;
          headline = isArabic ? 'جولة للخصم' : 'Opponent Won Round';
          glyph = null; // No glyph on loss
        }
      } else {
        themeColor = AppTokens.amberGold;
        headline = strings.winnerWon(state.roundWinner!.symbol);
        glyph = const TrophyGlyphWidget(size: 28);
      }
    } else {
      // Draw: calm cyan, NO gold, NO trophy
      themeColor = AppTokens.cyan;
      headline = isArabic ? 'تعادل — مباراة متكافئة' : strings.roundDrawMessage;
      glyph = const DrawGlyphWidget(size: 26);
    }

    final seconds = transitionSecondsRemaining > 0 ? transitionSecondsRemaining : 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor,
          width: (isWon && isHumanWinner) ? 1.8 : 1.2,
        ),
        boxShadow: (isWon && isHumanWinner)
            ? [
                BoxShadow(
                  color: AppTokens.amberGold.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (glyph != null) ...[
            glyph,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    color: (isWon && !isHumanWinner)
                        ? AppTokens.textSecondary
                        : AppTokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.nextRoundIn(seconds),
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
              backgroundColor: themeColor.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: themeColor.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: onNextRound,
            child: Text(
              strings.nextRoundNow,
              style: TextStyle(
                color: themeColor,
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
