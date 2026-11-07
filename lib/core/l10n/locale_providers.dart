import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_strings.dart';

/// Initial language (Arabic — primary/RTL — by default). Tests may override
/// this value; the language-toggle flow uses the real [LocaleController].
final localeInitialProvider = Provider<bool>((ref) => true);

/// Whether the app currently displays Arabic (true — primary/RTL default)
/// or English (false).
final localeProvider = NotifierProvider<LocaleController, bool>(LocaleController.new);

/// Controls the active app language.
class LocaleController extends Notifier<bool> {
  @override
  bool build() => ref.watch(localeInitialProvider);

  void toggle() => state = !state;
}

/// Centralized bilingual strings derived from the active locale.
/// Widgets watch this instead of receiving [AppStrings] through constructors,
/// eliminating manual prop-drilling.
final stringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(isArabic: ref.watch(localeProvider)),
);
