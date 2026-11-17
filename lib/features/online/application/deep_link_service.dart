import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/room_code.dart';

/// Service managing invite links (`https://.../join?code=...`) and custom
/// scheme deep links (`xoneon://join?code=...`) for online rooms.
class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  /// Custom scheme used by the application.
  static const String scheme = 'xoneon';

  /// Host used for joining rooms.
  static const String joinHost = 'join';

  /// Canonical HTTPS origin used for shared invites.
  ///
  /// Messaging apps only reliably linkify `http`/`https` URLs, so the invite
  /// text uses this origin instead of the custom scheme. The static fallback
  /// page lives in `web/join/index.html` and is deployed with Firebase Hosting
  /// (see `firebase.json`).
  static const String inviteBaseUrl = 'https://xo-neon-online.web.app';

  /// Constructs the public HTTPS invite URL containing only the 6-character
  /// room code. Never embeds user IDs, tokens, or private secrets.
  ///
  /// [languageCode] optionally adds `lang=ar` or `lang=en` so the fallback
  /// page opens in the sender's language.
  static String createInviteLink(String rawCode, {String? languageCode}) {
    final code = RoomCode.normalize(rawCode);
    final lang = _normalizeLanguage(languageCode);
    final query = lang == null ? 'code=$code' : 'code=$code&lang=$lang';
    return '$inviteBaseUrl/$joinHost?$query';
  }

  /// Constructs the custom-scheme link used by the fallback page's
  /// "Open in App" button. Kept for backward compatibility and for browsers
  /// that cannot hand off an HTTPS App Link.
  static String createAppLink(String rawCode) {
    final code = RoomCode.normalize(rawCode);
    return '$scheme://$joinHost?code=$code';
  }

  static String? _normalizeLanguage(String? languageCode) {
    if (languageCode == null) return null;
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.startsWith('ar')) return 'ar';
    if (normalized.startsWith('en')) return 'en';
    return null;
  }

  /// Parses a deep link [Uri] and extracts the validated room code.
  /// Returns `null` if the link does not contain a valid room code.
  static String? parseRoomCode(Uri uri) {
    String? raw;

    // 1. Query parameter `code` (e.g. https://xo-neon-online.web.app/join?code=A7K9X2
    //    or the legacy xoneon://join?code=A7K9X2).
    if (uri.queryParameters.containsKey('code')) {
      raw = uri.queryParameters['code'];
    }
    // 2. Path segment fallback (e.g. xoneon://join/A7K9X2)
    else if (uri.pathSegments.isNotEmpty) {
      raw = uri.pathSegments.last;
    }

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final normalized = RoomCode.normalize(raw);
    return RoomCode.isValid(normalized) ? normalized : null;
  }

  /// Builds a friendly bilingual message with a clickable HTTPS invite link
  /// and a manual room-code fallback.
  static String createShareMessage({
    required String roomCode,
    required bool isArabic,
  }) {
    final link = createInviteLink(
      roomCode,
      languageCode: isArabic ? 'ar' : 'en',
    );
    if (isArabic) {
      return 'تحداني في مباراة XO نيون!\n'
          'انضم للغرفة عبر الرابط:\n$link\n\n'
          'رمز الغرفة: $roomCode\n'
          '(افتح الرابط للانضمام، أو أدخل رمز الغرفة يدويًا في التطبيق)';
    } else {
      return 'Challenge me to a game of XO Neon!\n'
          'Join the room via this link:\n$link\n\n'
          'Room Code: $roomCode\n'
          '(Open the link to join, or enter the room code manually in the app)';
    }
  }

  /// Reads initial deep link (e.g. app cold-started from tapping a link).
  Future<String?> getInitialCode() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        return parseRoomCode(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error retrieving initial link: $e');
    }
    return null;
  }

  /// Streams incoming room codes from deep links received while app is running.
  Stream<String> codeStream() {
    return _appLinks.uriLinkStream
        .map((uri) => parseRoomCode(uri))
        .where((code) => code != null)
        .cast<String>();
  }
}

/// Provider exposing the singleton [DeepLinkService].
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});
