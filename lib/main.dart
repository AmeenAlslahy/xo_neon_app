import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme/neon_colors.dart';
import 'app/theme/neon_theme.dart';
import 'core/l10n/locale_providers.dart';
import 'core/widgets/neon_button.dart';
import 'features/game/application/match_providers.dart';
import 'features/game/presentation/screens/home_screen.dart';
import 'features/online/application/active_session_tracker.dart';
import 'features/online/application/auth_service.dart';
import 'features/online/application/deep_link_service.dart';
import 'features/online/application/firebase_service.dart';
import 'features/online/application/room_service.dart';
import 'features/online/presentation/screens/join_room_screen.dart';

/// Global navigator key allowing deep link handling from background callbacks.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: rootNavigatorKey,
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
      home: const DeepLinkCoordinator(
        child: HomeScreen(),
      ),
    );
  }
}

/// Listens for deep links (both cold start and runtime events) and routes to
/// [JoinRoomScreen] with pre-filled room code without auto-joining.
/// If an active session is in progress, prompts the user before switching.
class DeepLinkCoordinator extends ConsumerStatefulWidget {
  const DeepLinkCoordinator({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<DeepLinkCoordinator> createState() =>
      _DeepLinkCoordinatorState();
}

class _DeepLinkCoordinatorState extends ConsumerState<DeepLinkCoordinator> {
  StreamSubscription<String>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
    });
  }

  Future<void> _initDeepLinks() async {
    final service = ref.read(deepLinkServiceProvider);

    // 1. Cold start link
    final initialCode = await service.getInitialCode();
    if (initialCode != null && mounted) {
      _handleIncomingCode(initialCode);
    }

    // 2. Runtime link stream
    _linkSubscription = service.codeStream().listen((code) {
      if (mounted) {
        _handleIncomingCode(code);
      }
    });
  }

  Future<void> _handleIncomingCode(String code) async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    final activeSession = ref.read(activeSessionProvider);
    final strings = ref.read(stringsProvider);

    if (activeSession != null) {
      // Guard against silent replacement: prompt the user
      final shouldLeave = await showDialog<bool>(
        context: navContext,
        builder: (ctx) => AlertDialog(
          backgroundColor: NeonColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NeonColors.amberGold, width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.link_rounded,
                color: NeonColors.amberGold,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.activeSessionInviteTitle,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            strings.activeSessionInviteMessage(code),
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                strings.stayInCurrentSession,
                style: const TextStyle(
                  color: NeonColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            NeonButton(
              label: strings.leaveAndJoinNew,
              color: NeonColors.cyanX,
              isSolid: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );

      if (shouldLeave != true || !navContext.mounted) return;

      final roomService = ref.read(roomServiceProvider);
      final auth = ref.read(authServiceProvider);
      final uid = auth.currentUid ?? '';

      while (navContext.mounted) {
        final result = await roomService.leaveRoom(
          roomCode: activeSession.roomCode,
          uid: uid,
          isHost: activeSession.isHost,
          isMatch: activeSession.isInGame,
        );

        if (result is LeaveRoomSuccess) {
          if (navContext.mounted) {
            ref.read(activeSessionProvider.notifier).forceClear();
            Navigator.of(navContext).popUntil((route) => route.isFirst);
            Navigator.of(navContext).push(
              MaterialPageRoute(
                builder: (_) => JoinRoomScreen(initialCode: code),
              ),
            );
          }
          return;
        }

        // On failure: do NOT navigate. Show Retry and Cancel options only (NO "leave anyway")
        if (!navContext.mounted) return;
        final action = await showDialog<String>(
          context: navContext,
          barrierDismissible: false,
          builder: (errCtx) => AlertDialog(
            backgroundColor: NeonColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: NeonColors.dangerRed, width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: NeonColors.dangerRed, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.isArabic ? 'خطأ في الاتصال' : 'Connection Error',
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              strings.leaveErrorConnection,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(errCtx).pop('cancel'),
                child: Text(
                  strings.cancel,
                  style: const TextStyle(color: NeonColors.textSecondary),
                ),
              ),
              NeonButton(
                label: strings.retry,
                color: NeonColors.cyanX,
                isSolid: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onPressed: () => Navigator.of(errCtx).pop('retry'),
              ),
            ],
          ),
        );

        if (action != 'retry') {
          return;
        }
      }
    } else {
      // No active session: navigate directly to JoinRoomScreen with code pre-filled
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => JoinRoomScreen(initialCode: code),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
