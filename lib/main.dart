import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme/neon_theme.dart';
import 'core/l10n/locale_providers.dart';
import 'features/game/application/match_providers.dart';
import 'features/game/presentation/screens/home_screen.dart';
import 'features/online/application/auth_service.dart';
import 'features/online/application/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init note: $e');
  }

  try {
    await FirebaseService.initialize();
    await AuthService().ensureSignedIn();
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const XoNeonApp(),
    ),
  );
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
