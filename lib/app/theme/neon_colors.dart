import 'package:flutter/material.dart';

/// Central palette for XO Neon — unified across all screens.
/// Purple is used only for backgrounds, surfaces and decorative detail;
/// never as a selection indicator or primary action colour.
class NeonColors {
  NeonColors._();

  // ── Background & Surface Layers ───────────────────────────────────────────
  static const Color background     = Color(0xFF080611); // deepest layer
  static const Color surface        = Color(0xFF140F26); // card surface
  static const Color surfaceGlass   = Color(0xFF140F26); // alias kept for compat
  static const Color surfaceElevated= Color(0xFF1B1530); // raised surface / glass
  static const Color borderSubtle   = Color(0xFF35294D); // quiet separator

  // ── Board-specific (unchanged) ────────────────────────────────────────────
  static const Color boardSurface   = Color(0xFF0E0924);
  static const Color boardGridLine  = Color(0xFF2D1D52);
  static const Color boardGridLineGlow = Color(0x448B5CF6);

  // ── Purple / Violet — backgrounds & decorative only ──────────────────────
  static const Color purpleNeon    = Color(0xFF9D4EDD);
  static const Color purpleAccent  = Color(0xFF7928CA);
  static const Color purpleGlow    = Color(0x669D4EDD);
  static const Color purpleBorder  = Color(0xFF8B5CF6);

  // ── Player X — Cyan (primary identity & action) ───────────────────────────
  static const Color cyanX      = Color(0xFF13D5E4);
  static const Color cyanGlow   = Color(0x6613D5E4);
  static const Color cyanShadow = Color(0x3313D5E4);

  // ── Player O — Coral (secondary identity) ─────────────────────────────────
  static const Color orangeO      = Color(0xFFFF6A4B);
  static const Color orangeGlow   = Color(0x66FF6A4B);
  static const Color orangeShadow = Color(0x33FF6A4B);

  // Backward-compatibility aliases
  static const Color magentaO      = orangeO;
  static const Color magentaGlow   = orangeGlow;
  static const Color magentaShadow = orangeShadow;

  // ── Gold — warning / celebratory accent ───────────────────────────────────
  static const Color amberGold = Color(0xFFF4BD3E);
  static const Color amberGlow = Color(0x66F4BD3E);

  // ── Danger Red — destructive actions only ─────────────────────────────────
  static const Color dangerRed     = Color(0xFFE94D45);
  static const Color dangerRedGlow = Color(0x66E94D45);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF5F2FA);
  static const Color textSecondary = Color(0xFFB5AEC3);
  static const Color textMuted     = Color(0xFF7A6F8A); // raised from #64748B

  // ── Background gradient ───────────────────────────────────────────────────
  static BoxDecoration get cyberBackground => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0C0720),
            Color(0xFF08060F),
            Color(0xFF100C22),
          ],
        ),
      );

  // ── Glow helpers (intentionally subtle) ──────────────────────────────────
  /// Use sparingly: active state, current player card, winning line only.
  static List<BoxShadow> glow({
    required Color color,
    double blur = 10.0,
    double spread = 0.5,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.15),
        blurRadius: blur * 1.8,
        spreadRadius: spread,
      ),
    ];
  }

  /// Stronger glow for the active/winning player card or winning cell.
  static List<BoxShadow> activeGlow({required Color color}) =>
      glow(color: color, blur: 14, spread: 1.0);
}
