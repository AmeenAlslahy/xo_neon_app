import 'package:flutter/material.dart';
import 'neon_colors.dart';

/// App theme providing cyber-neon styling across all widgets.
class NeonTheme {
  NeonTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NeonColors.background,
      colorScheme: const ColorScheme.dark(
        primary: NeonColors.cyanX,
        secondary: NeonColors.magentaO,
        surface: NeonColors.surface,
        onSurface: NeonColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: NeonColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
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
          side: const BorderSide(color: NeonColors.purpleBorder, width: 1.5),
        ),
      ),
    );
  }
}
