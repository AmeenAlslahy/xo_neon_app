import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/theme/neon_theme.dart';
import 'features/game/presentation/screens/home_screen.dart';

void main() {
  runApp(const XoNeonApp());
}

/// Root application widget configuring dark theme, RTL Arabic support, and screen flow.
class XoNeonApp extends StatefulWidget {
  const XoNeonApp({super.key});

  @override
  State<XoNeonApp> createState() => _XoNeonAppState();
}

class _XoNeonAppState extends State<XoNeonApp> {
  bool _isArabic = true;

  void _toggleLanguage() {
    setState(() => _isArabic = !_isArabic);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XO Neon',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.darkTheme,
      locale: Locale(_isArabic ? 'ar' : 'en'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeScreen(
        isArabic: _isArabic,
        onToggleLanguage: _toggleLanguage,
      ),
    );
  }
}
