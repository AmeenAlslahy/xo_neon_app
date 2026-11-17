import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'deep_link_service.dart';

typedef ShareFunction = Future<ShareResult> Function(
  String text, {
  String? subject,
  Rect? sharePositionOrigin,
});

/// Service managing system share sheets for room invites.
class ShareService {
  ShareService({ShareFunction? shareFn})
      : _shareFn = shareFn ??
            ((text, {subject, sharePositionOrigin}) =>
                SharePlus.instance.share(
                  ShareParams(
                    text: text,
                    subject: subject,
                    sharePositionOrigin: sharePositionOrigin,
                  ),
                ));

  final ShareFunction _shareFn;

  /// Opens the system share sheet with an invitation containing the room code and deep link.
  Future<ShareResult> shareRoomInvite({
    required String roomCode,
    required bool isArabic,
    Rect? sharePositionOrigin,
  }) async {
    final message = DeepLinkService.createShareMessage(
      roomCode: roomCode,
      isArabic: isArabic,
    );
    final subject = isArabic ? 'دعوة لمباراة XO نيون' : 'XO Neon Match Invite';

    return _shareFn(
      message,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}

/// Provider exposing [ShareService].
final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService();
});
