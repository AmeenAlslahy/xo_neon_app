import 'dart:async';

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

/// Local settings are the only startup dependency: they are a tiny local
/// read and the UI immediately picks up the persisted sound/language state.
/// The timeout guarantees a wedged platform channel cannot hold the splash
/// screen hostage (the app then starts with default settings).
const Duration _prefsTimeout = Duration(seconds: 3);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
  } on TimeoutException {
    debugPrint('SharedPreferences init timed out; using defaults');
  } catch (e) {
    debugPrint('SharedPreferences init note: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const XoNeonApp(),
    ),
  );

  // Online services need Firebase plus an anonymous auth round-trip, which
  // may take seconds (or wait for a network timeout) on a cold start. None of
  // that is needed to render the home screen, so it runs only after the first
  // frame. Create/join room flows await initialization before touching
  // Firebase, and the connection badge subscribes once initialization ends.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(FirebaseService.initialize());
    unawaited(AuthService().ensureSignedIn());
  });
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
