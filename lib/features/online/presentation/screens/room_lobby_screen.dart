import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../../../core/widgets/sticky_bottom_bar.dart';
import '../../application/active_session_tracker.dart';
import '../../application/auth_service.dart';
import '../../application/room_service.dart';
import '../../application/share_service.dart';
import '../../domain/logic/online_transactions.dart';
import '../../domain/models/room_model.dart';
import '../widgets/player_slot_card.dart';
import '../widgets/room_code_display.dart';
import '../widgets/room_settings_sheet.dart';
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
  bool _isSavingConfig = false;
  bool _isLeavingInProgress = false;
  ActiveSessionNotifier? _activeSessionNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activeSessionNotifier = ref.read(activeSessionProvider.notifier);
        _activeSessionNotifier?.setActiveSession(
          ActiveSession(
            roomCode: widget.roomCode,
            isHost: widget.isHost,
            isInGame: false,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    final notifier = _activeSessionNotifier;
    final code = widget.roomCode;
    Future.microtask(() => notifier?.clear(code, onlyIfLobby: true));
    super.dispose();
  }

  Future<void> _handleStartGame(RoomModel room) async {
    if (_isStarting || _isSavingConfig) return;
    setState(() => _isStarting = true);

    final roomService = ref.read(roomServiceProvider);
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUid ?? room.hostUid;
    final strings = ref.read(stringsProvider);
    bool registeredDisconnect = false;

    try {
      // 1. Guard against starting if already inGame (do not re-initialize /game)
      final latestRoom = await roomService.getRoom(widget.roomCode) ?? room;
      if (latestRoom.status == RoomStatus.inGame) {
        _showSnackBar(
          strings.isArabic
              ? 'المباراة بدأت بالفعل'
              : 'Match has already started',
        );
        return;
      }

      // 2. Register host in-game disconnect before atomic start
      await roomService.registerHostInGameDisconnect(
        roomCode: widget.roomCode,
        hostUid: uid,
      );
      registeredDisconnect = true;

      // 3. Start match atomically: updates room.status = inGame and creates game = initialState in one transaction
      final startResult = await roomService.startMatchAtomic(
        roomCode: widget.roomCode,
        hostUid: uid,
      );

      if (!mounted) return;

      switch (startResult) {
        case StartMatchSuccess():
          // Success: room listener will auto-transition to OnlineGameBoardScreen
          break;
        case StartMatchFailure(:final reason):
          // Roll back: cancel in-game disconnect and restore lobby disconnect
          await roomService.cancelDisconnectHandlers(widget.roomCode);
          registeredDisconnect = false;
          await roomService.registerHostLobbyDisconnect(
            roomCode: widget.roomCode,
            hostUid: uid,
          );

          final msg = switch (reason) {
            StartMatchFailureReason.alreadyInGame =>
              strings.isArabic
                  ? 'المباراة بدأت بالفعل'
                  : 'Match has already started',
            StartMatchFailureReason.guestMissing =>
              strings.isArabic
                  ? 'غادر الضيف الغرفة، لا يمكن بدء المباراة'
                  : 'Guest left, cannot start match',
            StartMatchFailureReason.notReady =>
              strings.isArabic
                  ? 'الغرفة ليست جاهزة بعد'
                  : 'Room is not ready yet',
            _ =>
              strings.isArabic ? 'فشل بدء المباراة' : 'Failed to start match',
          };
          _showSnackBar(msg, isError: true);
      }
    } catch (e) {
      debugPrint('Failed to start match: $e');
      if (registeredDisconnect) {
        await roomService.cancelDisconnectHandlers(widget.roomCode);
        await roomService.registerHostLobbyDisconnect(
          roomCode: widget.roomCode,
          hostUid: uid,
        );
      }
      if (mounted) {
        // Never surface a raw Firebase/exception string to the player.
        _showSnackBar(strings.serviceUnavailable, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  /// Lets the host change board size / rounds from inside the waiting room.
  ///
  /// The update is written to Firebase, so the guest's live room stream
  /// refreshes the summary immediately without leaving the lobby.
  Future<void> _openRoomSettings(RoomModel room) async {
    if (!widget.isHost || _isSavingConfig) return;

    final strings = ref.read(stringsProvider);
    final newConfig = await showRoomSettingsSheet(
      context,
      initialConfig: room.config,
      isArabic: strings.isArabic,
    );

    if (newConfig == null || !mounted || newConfig == room.config) return;

    setState(() => _isSavingConfig = true);
    try {
      // Use the UID stored on the room instead of the ambient auth session:
      // offline/unauthenticated rooms use a generated local host UID, and the
      // host must still be able to edit settings in that mode.
      final result = await ref
          .read(roomServiceProvider)
          .updateRoomConfig(
            roomCode: widget.roomCode,
            hostUid: room.hostUid,
            config: newConfig,
          );

      if (!mounted) return;

      switch (result) {
        case UpdateRoomConfigSuccess():
          _showSnackBar(strings.roomSettingsUpdated);
        case UpdateRoomConfigNotAllowed(:final reason):
          final message = switch (reason) {
            'not_host' => strings.roomSettingsHostOnly,
            'game_started' => strings.roomSettingsLocked,
            _ => strings.roomSettingsUpdateFailed,
          };
          _showSnackBar(message, isError: true);
        case UpdateRoomConfigFailure():
          _showSnackBar(strings.roomSettingsUpdateFailed, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingConfig = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final color = isError ? NeonColors.dangerRed : NeonColors.cyanX;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: NeonColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color, width: 1.2),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Handles leaving with explicit confirmation and retry error handling on network failure.
  Future<bool> _confirmLeave(BuildContext context) async {
    if (_isLeavingInProgress) return false;

    final strings = ref.read(stringsProvider);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTokens.borderSubtle, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTokens.dangerRed,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.isArabic ? 'مغادرة الغرفة؟' : 'Leave Room?',
                style: const TextStyle(
                  color: AppTokens.textPrimary,
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
            color: AppTokens.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              strings.isArabic ? 'البقاء' : 'Stay',
              style: const TextStyle(
                color: AppTokens.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          NeonButton(
            label: strings.isArabic ? 'مغادرة' : 'Leave',
            isOutlineDanger: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.isArabic ? 'مغادرة' : 'Leave',
                  style: const TextStyle(
                    color: AppTokens.dangerRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(
                  width: 0,
                  height: 0,
                  child: Text(
                    strings.leaveRoom,
                    style: const TextStyle(fontSize: 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (shouldLeave != true || !mounted) {
      return false;
    }

    return _executeLeave();
  }

  Future<bool> _executeLeave() async {
    _isLeavingInProgress = true;
    final strings = ref.read(stringsProvider);
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUid ?? '';

    while (mounted) {
      final result = await ref
          .read(roomServiceProvider)
          .leaveRoom(
            roomCode: widget.roomCode,
            uid: uid,
            isHost: widget.isHost,
            isMatch: false,
          );

      if (result is LeaveRoomSuccess) {
        _isLeavingInProgress = false;
        ref.read(activeSessionProvider.notifier).clear(widget.roomCode);
        return true;
      }

      if (!mounted) {
        _isLeavingInProgress = false;
        return true;
      }

      // If writing leave event failed due to network, show error with Retry / Leave Anyway / Cancel
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (errCtx) => AlertDialog(
          backgroundColor: NeonColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NeonColors.dangerRed, width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: NeonColors.dangerRed,
                size: 24,
              ),
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
            TextButton(
              onPressed: () => Navigator.of(errCtx).pop('leave_anyway'),
              child: Text(
                strings.leaveAnyway,
                style: const TextStyle(color: NeonColors.amberGold),
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

      if (action == 'retry') {
        continue;
      } else if (action == 'leave_anyway') {
        _isLeavingInProgress = false;
        ref.read(activeSessionProvider.notifier).clear(widget.roomCode);
        return true;
      } else {
        _isLeavingInProgress = false;
        return false;
      }
    }

    _isLeavingInProgress = false;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final roomAsync = ref.watch(roomStreamProvider(widget.roomCode));
    final currentUid = ref.watch(authServiceProvider).currentUid ?? '';

    // Listen for room updates:
    // 1. Auto-transition to match when game starts.
    // 2. Notify host when guest leaves the waiting room (one distinct notification).
    ref.listen<AsyncValue<RoomModel?>>(roomStreamProvider(widget.roomCode), (
      prev,
      next,
    ) {
      final prevRoom = prev?.value;
      final currentRoom = next.value;

      // Auto-transition to active match
      if (currentRoom != null &&
          currentRoom.status == RoomStatus.inGame &&
          context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                OnlineGameBoardScreen(room: currentRoom, isHost: widget.isHost),
          ),
        );
        return;
      }

      // Host notification when guest vacates the seat in lobby
      if (widget.isHost &&
          prevRoom != null &&
          prevRoom.isFull &&
          currentRoom != null &&
          !currentRoom.isFull &&
          currentRoom.status == RoomStatus.waitingForGuest &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.guestLeftLobby,
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: NeonColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: NeonColors.amberGold, width: 1.2),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Guest notification when the host edits settings from the lobby.
      if (!widget.isHost &&
          prevRoom != null &&
          currentRoom != null &&
          prevRoom.config != currentRoom.config &&
          currentRoom.status != RoomStatus.inGame &&
          context.mounted) {
        _showSnackBar(strings.guestUpdatedRoomSettings);
      }
    });

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
        backgroundColor: AppTokens.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            strings.isArabic ? 'غرفة الانتظار' : 'Waiting Lobby',
            style: AppTokens.screenTitleStyle,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTokens.cyan),
            tooltip: strings.leaveRoom,
            onPressed: () async {
              final shouldLeave = await _confirmLeave(context);
              if (shouldLeave && context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTokens.maxTabletContentWidth,
                ),
                child: roomAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.cyan),
                    ),
                  ),
                  error: (err, _) {
                    debugPrint('Error loading room: $err');
                    return Center(
                      child: Text(
                        strings.roomNotFound,
                        style: const TextStyle(color: AppTokens.dangerRed),
                      ),
                    );
                  },
                  data: (room) {
                    // Room abandoned / terminated
                    if (room == null ||
                        room.isTerminated ||
                        room.status == RoomStatus.abandoned) {
                      final isHostLeft = room?.termination?.byRole == 'host';
                      final isGuestLeft = room?.termination?.byRole == 'guest';
                      final terminationMessage = isHostLeft
                          ? (widget.isHost
                              ? strings.hostLeftMatch
                              : strings.sessionTerminatedByHost)
                          : isGuestLeft
                              ? strings.guestLeftMatch
                              : (room?.termination?.message ??
                                  strings.roomStatusAbandoned);

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.link_off_rounded,
                                color: AppTokens.dangerRed,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                terminationMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTokens.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              NeonButton(
                                label: strings.isArabic
                                    ? 'العودة للرئيسية'
                                    : 'Return Home',
                                color: AppTokens.cyan,
                                isSolid: true,
                                onPressed: () async {
                                  ref
                                      .read(activeSessionProvider.notifier)
                                      .clear(widget.roomCode);
                                  await ref
                                      .read(roomServiceProvider)
                                      .cancelDisconnectHandlers(
                                        widget.roomCode,
                                      );
                                  if (context.mounted) {
                                    Navigator.of(context)
                                        .popUntil((route) => route.isFirst);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // If room entered inGame status, show game starting banner
                    final isGameStarting = room.status == RoomStatus.inGame;

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Room Code Header (Neutral, no glow)
                                RoomCodeDisplay(code: room.code),

                                // Host: Share Invite Button (Solid Cyan when waiting, secondary when ready)
                                if (widget.isHost) ...[
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (btnCtx) => NeonButton(
                                      label: strings.shareInvite,
                                      icon: Icons.share_rounded,
                                      color: AppTokens.cyan,
                                      isSolid: !room.isReady,
                                      isSecondary: room.isReady,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      onPressed: () {
                                        final box =
                                            btnCtx.findRenderObject()
                                                as RenderBox?;
                                        final origin = box != null
                                            ? box.localToGlobal(Offset.zero) &
                                                  box.size
                                            : null;
                                        ref
                                            .read(shareServiceProvider)
                                            .shareRoomInvite(
                                              roomCode: room.code,
                                              isArabic: strings.isArabic,
                                              sharePositionOrigin: origin,
                                            );
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Match Config Summary Card.
                                NeonCard(
                                  key: const ValueKey('roomSettingsCard'),
                                  borderColor: AppTokens.borderSubtle,
                                  padding: const EdgeInsets.all(16),
                                  onTap: widget.isHost && !_isSavingConfig
                                      ? () => _openRoomSettings(room)
                                      : null,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Text(
                                                  strings.boardSizeLabel,
                                                  style: AppTokens.captionStyle,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${room.config.boardSize}×${room.config.boardSize}',
                                                  style: const TextStyle(
                                                    color:
                                                        AppTokens.textPrimary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            height: 30,
                                            width: 1,
                                            color: AppTokens.borderSubtle,
                                          ),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Text(
                                                  strings.roundsToWinLabel,
                                                  style: AppTokens.captionStyle,
                                                ),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    room.config.roundsToWin == 1
                                                        ? (strings.isArabic
                                                              ? 'الفائز: ١ من ١'
                                                              : 'Winner: 1 of 1')
                                                        : (room.config.roundsToWin ==
                                                                  2
                                                              ? (strings.isArabic
                                                                    ? 'الفائز: ٢ من ٣ جولات'
                                                                    : 'Winner: 2 of 3')
                                                              : (strings.isArabic
                                                                    ? 'الفائز: ٣ من ٥ جولات'
                                                                    : 'Winner: 3 of 5')),
                                                    style: const TextStyle(
                                                      color:
                                                          AppTokens.textPrimary,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (widget.isHost) ...[
                                        const SizedBox(height: 14),
                                        NeonButton(
                                          label: _isSavingConfig
                                              ? strings.connectionConnecting
                                              : strings.editRoomSettings,
                                          icon: Icons.tune_rounded,
                                          isSecondary: true,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          onPressed:
                                              widget.isHost && !_isSavingConfig
                                              ? () => _openRoomSettings(room)
                                              : null,
                                        ),
                                      ],
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
                                const SizedBox(height: 24),

                                // Explicit Leave Room danger outline button
                                NeonButton(
                                  label: strings.isArabic
                                      ? 'مغادرة الغرفة'
                                      : 'Leave Room',
                                  icon: Icons.exit_to_app_rounded,
                                  isOutlineDanger: true,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  onPressed: () async {
                                    final shouldLeave = await _confirmLeave(
                                      context,
                                    );
                                    if (shouldLeave && context.mounted) {
                                      Navigator.of(context)
                                          .popUntil((route) => route.isFirst);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Sticky Bottom Bar: Pinned Start Game or Waiting Container
                        StickyBottomBar(
                          child: isGameStarting
                              ? Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTokens.cyan.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTokens.cyan,
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
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppTokens.cyan,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        strings.isArabic
                                            ? 'المباراة تبدأ الآن...'
                                            : 'Match is starting...',
                                        style: const TextStyle(
                                          color: AppTokens.cyan,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : (widget.isHost
                                    ? NeonButton(
                                        label: room.isReady
                                            ? (_isStarting
                                                  ? strings.connectionConnecting
                                                  : strings.startGame)
                                            : (strings.isArabic
                                                  ? 'بانتظار انضمام الصديق…'
                                                  : 'Waiting for player...'),
                                        color: AppTokens.cyan,
                                        isSolid: room.isReady,
                                        isSecondary: !room.isReady,
                                        isDisabled:
                                            !room.isReady ||
                                            _isStarting ||
                                            _isSavingConfig,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        onPressed:
                                            (room.isReady &&
                                                !_isStarting &&
                                                !_isSavingConfig)
                                            ? () => _handleStartGame(room)
                                            : null,
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTokens.surfaceElevated,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppTokens.borderSubtle,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            strings.waitingForHost,
                                            style: const TextStyle(
                                              color: AppTokens.textSecondary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
