import 'package:flutter/material.dart';
import 'neon_colors.dart';

/// App theme — cyber-neon styling with unified token usage.
class NeonTheme {
  NeonTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NeonColors.background,
      colorScheme: const ColorScheme.dark(
        primary: NeonColors.cyanX,
        secondary: NeonColors.orangeO,
        surface: NeonColors.surface,
        onSurface: NeonColors.textPrimary,
        error: NeonColors.dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: NeonColors.cyanX),
        titleTextStyle: TextStyle(
          color: NeonColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      cardTheme: CardThemeData(
        color: NeonColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NeonColors.borderSubtle, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NeonColors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NeonColors.borderSubtle, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return NeonColors.cyanX;
          return NeonColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return NeonColors.cyanX.withValues(alpha: 0.35);
          }
          return NeonColors.borderSubtle;
        }),
      ),
    );
  }
}
