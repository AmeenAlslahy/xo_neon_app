import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme/neon_theme.dart';
import 'core/l10n/locale_providers.dart';
import 'features/game/presentation/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: XoNeonApp()));
}

/// Root application widget configuring dark theme, RTL Arabic support, and
/// screen flow. The active language lives in [localeProvider].
class XoNeonApp extends ConsumerWidget {
  const XoNeonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = ref.watch(localeProvider);
    return MaterialApp(
      title: 'XO Neon',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.darkTheme,
      locale: Locale(isArabic ? 'ar' : 'en'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
