import 'package:flutter/material.dart';

/// Central palette of dark cyber-neon colors, purple accents, and multi-layered glows.
class NeonColors {
  NeonColors._();

  // Dark background foundations with purple undertones
  static const Color background = Color(0xFF080516);
  static const Color surface = Color(0xFF100B26);
  static const Color surfaceGlass = Color(0xCC150E33);
  static const Color borderSubtle = Color(0xFF261A4D);

  // Purple / Violet Neon Accents (Visual Reference)
  static const Color purpleNeon = Color(0xFF9D4EDD);
  static const Color purpleAccent = Color(0xFF7928CA);
  static const Color purpleGlow = Color(0x669D4EDD);
  static const Color purpleBorder = Color(0xFF8B5CF6);
  static const Color boardSurface = Color(0xFF0E0924);
  static const Color boardGridLine = Color(0xFF2D1D52);
  static const Color boardGridLineGlow = Color(0x448B5CF6);

  // Player X (Cyan / Electric Sky Blue)
  static const Color cyanX = Color(0xFF00E5FF);
  static const Color cyanGlow = Color(0x6600E5FF);
  static const Color cyanShadow = Color(0x3300E5FF);

  // Player O (Vibrant Neon Red-Orange / Coral Flame as mandated by visual guidelines)
  static const Color orangeO = Color(0xFFFF3D00);
  static const Color orangeGlow = Color(0x66FF3D00);
  static const Color orangeShadow = Color(0x33FF3D00);

  // Backward compatibility aliases for existing references
  static const Color magentaO = orangeO;
  static const Color magentaGlow = orangeGlow;
  static const Color magentaShadow = orangeShadow;

  // Amber / Gold (Draws, highlight badges, victory lines)
  static const Color amberGold = Color(0xFFFFB800);
  static const Color amberGlow = Color(0x66FFB800);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Cyber atmospheric background gradient
  static BoxDecoration get cyberBackground => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0C0720),
            Color(0xFF070414),
            Color(0xFF0F0A2A),
          ],
        ),
      );

  // Box shadows generators
  static List<BoxShadow> glow({
    required Color color,
    double blur = 14.0,
    double spread = 1.0,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.45),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.2),
        blurRadius: blur * 2,
        spreadRadius: spread * 1.5,
      ),
    ];
  }
}
