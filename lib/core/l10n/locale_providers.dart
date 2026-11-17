import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/game/application/match_providers.dart';
import 'app_strings.dart';

const String prefLocaleArabic = 'pref_locale_is_arabic';

/// Initial language (checks persisted settings first, then Arabic default).
/// Tests may override this provider directly.
final localeInitialProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final saved = prefs?.getBool(prefLocaleArabic);
  if (saved != null) {
    return saved;
  }
  return true; // Arabic by default
});

/// Whether the app currently displays Arabic (true — primary/RTL default)
/// or English (false).
final localeProvider = NotifierProvider<LocaleController, bool>(LocaleController.new);

/// Controls the active app language with persistence.
class LocaleController extends Notifier<bool> {
  @override
  bool build() => ref.watch(localeInitialProvider);

  void toggle() {
    final next = !state;
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(prefLocaleArabic, next);
  }

  void setArabic(bool isArabic) {
    state = isArabic;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(prefLocaleArabic, isArabic);
  }
}

/// Centralized bilingual strings derived from the active locale.
/// Widgets watch this instead of receiving [AppStrings] through constructors,
/// eliminating manual prop-drilling.
final stringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(isArabic: ref.watch(localeProvider)),
);
