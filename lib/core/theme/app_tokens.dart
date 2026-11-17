import 'package:flutter/material.dart';

/// Central Design Tokens for XO Neon (UX-CLARITY-02).
/// Unified single source of truth for colors, typography, breakpoints, and selection rules.
class AppTokens {
  AppTokens._();

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF080611);
  static const Color surface = Color(0xFF140F26);
  static const Color surfaceElevated = Color(0xFF1B1530);
  static const Color borderSubtle = Color(0xFF35294D);

  // Text
  static const Color textPrimary = Color(0xFFF5F2FA);
  static const Color textSecondary = Color(0xFFC9C3D6); // Description / secondary (>=4.5:1 on surface)
  static const Color textMuted = Color(0xFFB5AEC3);     // Muted / label
  static const Color textOnCyan = Color(0xFF061018);    // High contrast dark text on cyan fill

  // Accents
  static const Color cyan = Color(0xFF13D5E4);          // X + Primary action + All selections
  static const Color coral = Color(0xFFFF6A4B);         // O identity only
  static const Color amberGold = Color(0xFFF4BD3E);     // Warning / celebration / pause
  static const Color dangerRed = Color(0xFFE94D45);     // Dangerous action only

  // Decorative / Surface purples
  static const Color purpleSurface = Color(0xFF1B1530);
  static const Color purpleBorder = Color(0xFF35294D);

  // ── Typography ────────────────────────────────────────────────────────────
  // Font sizes: minimum 12, no text below 12
  static const double fontScreenTitle = 20.0;
  static const double fontSectionTitle = 16.0;
  static const double fontCardTitle = 15.0;
  static const double fontBody = 13.0;
  static const double fontCaption = 12.0;

  static const TextStyle screenTitleStyle = TextStyle(
    fontSize: fontScreenTitle,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: fontSectionTitle,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle cardTitleStyle = TextStyle(
    fontSize: fontCardTitle,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: fontBody,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: fontCaption,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  // ── Selection Pattern ─────────────────────────────────────────────────────
  // Unified: Cyan 1.5dp border + 10% Cyan fill + Cyan checkmark
  static const double selectionBorderWidth = 1.5;
  static const double unselectedBorderWidth = 1.0;
  static const double selectionFillAlpha = 0.10;

  static BoxDecoration selectionDecoration({required bool isSelected}) {
    return BoxDecoration(
      color: isSelected
          ? cyan.withValues(alpha: selectionFillAlpha)
          : surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isSelected ? cyan : borderSubtle,
        width: isSelected ? selectionBorderWidth : unselectedBorderWidth,
      ),
    );
  }

  // ── Breakpoints & Layout ──────────────────────────────────────────────────
  static const double breakpointCompact = 360.0;
  static const double breakpointExpanded = 600.0;
  static const double maxTabletContentWidth = 520.0;
  static const double minTouchTargetSize = 44.0;
}

/// Motion Tokens for micro, meso, and macro celebration and UI transitions (UX-DELIGHT-01).
/// All celebration and UI animations must use durations from this centralized table.
abstract final class AppMotion {
  static const press      = Duration(milliseconds: 90);
  static const cellEnter  = Duration(milliseconds: 160);
  static const turnSwitch = Duration(milliseconds: 220);
  static const winLine    = Duration(milliseconds: 420);
  static const burst      = Duration(milliseconds: 600);
  static const banner     = Duration(milliseconds: 1800);
  static const screen     = Duration(milliseconds: 240);

  static const enter = Curves.easeOutCubic;
  static const pop   = Curves.easeOutBack;
}
