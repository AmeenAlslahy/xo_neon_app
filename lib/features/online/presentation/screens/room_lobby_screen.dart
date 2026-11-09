import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../application/auth_service.dart';
import '../../application/online_match_service.dart';
import '../../application/room_service.dart';
import '../../domain/models/room_model.dart';
import '../widgets/player_slot_card.dart';
import '../widgets/room_code_display.dart';
import 'online_game_board_screen.dart';

/// The waiting lobby screen for both the host and the joined guest.
class RoomLobbyScreen extends ConsumerStatefulWidget {
  const RoomLobbyScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  final String roomCode;
  final bool isHost;

  @override
  ConsumerState<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends ConsumerState<RoomLobbyScreen> {
  bool _isStarting = false;

  Future<void> _handleStartGame(RoomModel room) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      final auth = ref.read(authServiceProvider);
      final uid = auth.currentUid ?? '';
      await ref.read(onlineMatchServiceProvider).initializeGame(room);
      await ref.read(roomServiceProvider).startGame(
            roomCode: widget.roomCode,
            hostUid: uid,
          );
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final strings = ref.read(stringsProvider);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NeonColors.borderSubtle, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: NeonColors.dangerRed, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.leaveRoom,
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
          strings.leaveRoomConfirm,
          style: const TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              strings.isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          NeonButton(
            label: strings.leaveRoom,
            isDanger: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      final auth = ref.read(authServiceProvider);
      final uid = auth.currentUid ?? '';
      await ref.read(roomServiceProvider).leaveRoom(
            roomCode: widget.roomCode,
            uid: uid,
          );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final roomAsync = ref.watch(roomStreamProvider(widget.roomCode));
    final currentUid = ref.watch(authServiceProvider).currentUid ?? '';

    // Auto-transition both Host and Guest to the live match when game starts
    ref.listen<AsyncValue<RoomModel?>>(
      roomStreamProvider(widget.roomCode),
      (prev, next) {
        final room = next.value;
        if (room != null &&
            room.status == RoomStatus.inGame &&
            context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OnlineGameBoardScreen(
                room: room,
                isHost: widget.isHost,
              ),
            ),
          );
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeave(context);
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: NeonColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            strings.onlineLobbyTitle,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: NeonColors.cyanX),
            tooltip: strings.leaveRoom,
            onPressed: () async {
              final shouldLeave = await _confirmLeave(context);
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: roomAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NeonColors.cyanX),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading room: $err',
                  style: const TextStyle(color: NeonColors.dangerRed),
                ),
              ),
              data: (room) {
                if (room == null || room.status == RoomStatus.abandoned) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.link_off_rounded,
                            color: NeonColors.dangerRed,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            strings.roomStatusAbandoned,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: NeonColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          NeonButton(
                            label: strings.isArabic ? 'العودة للرئيسية' : 'Return Home',
                            color: NeonColors.cyanX,
                            isSolid: true,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // If room entered inGame status, show game starting banner
                final isGameStarting = room.status == RoomStatus.inGame;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Room Code Header
                      RoomCodeDisplay(code: room.code),
                      const SizedBox(height: 24),

                      // Match Config Summary Card
                      NeonCard(
                        borderColor: NeonColors.borderSubtle,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  strings.boardSizeLabel,
                                  style: const TextStyle(
                                    color: NeonColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${room.config.boardSize}x${room.config.boardSize}',
                                  style: const TextStyle(
                                    color: NeonColors.cyanX,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: NeonColors.borderSubtle,
                            ),
                            Column(
                              children: [
                                Text(
                                  strings.roundsToWinLabel,
                                  style: const TextStyle(
                                    color: NeonColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  room.config.roundsToWin == 1
                                      ? (strings.isArabic ? '1 جولة' : '1 Round')
                                      : (strings.isArabic
                                          ? 'فوز بـ ${AppStrings.toArabicDigits(room.config.roundsToWin)}'
                                          : 'First to ${room.config.roundsToWin}'),
                                  style: const TextStyle(
                                    color: NeonColors.cyanX,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Host Player Slot Card
                      PlayerSlotCard(
                        roleTitle: strings.host,
                        isHost: true,
                        playerName: room.hostName,
                        isOccupied: true,
                        isCurrentPlayer: room.isHost(currentUid),
                        waitingText: '',
                        youBadgeText: strings.you,
                      ),
                      const SizedBox(height: 16),

                      // Guest Player Slot Card
                      PlayerSlotCard(
                        roleTitle: strings.guest,
                        isHost: false,
                        playerName: room.guestName,
                        isOccupied: room.isFull,
                        isCurrentPlayer: room.isGuest(currentUid),
                        waitingText: strings.waitingForPlayer,
                        youBadgeText: strings.you,
                      ),
                      const SizedBox(height: 36),

                      // Status & Actions
                      if (isGameStarting) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: NeonColors.cyanX.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NeonColors.cyanX,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    NeonColors.cyanX,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                strings.isArabic
                                    ? 'المباراة تبدأ الآن...'
                                    : 'Match is starting...',
                                style: const TextStyle(
                                  color: NeonColors.cyanX,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (widget.isHost) ...[
                        if (room.isReady)
                          NeonButton(
                            label: _isStarting
                                ? strings.connectionConnecting
                                : strings.startGame,
                            color: NeonColors.cyanX,
                            isSolid: true,
                            onPressed: _isStarting
                                ? () {}
                                : () => _handleStartGame(room),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: NeonColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: NeonColors.borderSubtle,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      NeonColors.cyanX,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    strings.waitingForPlayer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NeonColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: NeonColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NeonColors.borderSubtle,
                              width: 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              strings.waitingForHost,
                              style: const TextStyle(
                                color: NeonColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
