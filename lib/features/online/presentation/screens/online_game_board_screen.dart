import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../../game/domain/logic/game_board.dart';
import '../../../game/domain/models/board_config.dart';
import '../../../game/domain/models/cell_position.dart';
import '../../../game/domain/models/player.dart';
import '../../../game/domain/models/winning_line.dart';
import '../../../game/presentation/widgets/game_grid_widget.dart';
import '../../application/active_session_tracker.dart';
import '../../application/auth_service.dart';
import '../../application/connection_status_provider.dart';
import '../../application/online_match_service.dart';
import '../../application/room_service.dart';
import '../../domain/logic/online_transactions.dart';
import '../../domain/logic/termination_resolver.dart';
import '../../domain/models/online_game_state.dart';
import '../../domain/models/room_model.dart';
import '../widgets/connection_status_badge.dart';
import '../widgets/room_settings_sheet.dart';
import 'room_lobby_screen.dart';

/// Screen hosting a live, synchronized online multiplayer match over Firebase.
class OnlineGameBoardScreen extends ConsumerStatefulWidget {
  const OnlineGameBoardScreen({
    super.key,
    required this.room,
    required this.isHost,
  });

  final RoomModel room;
  final bool isHost;

  @override
  ConsumerState<OnlineGameBoardScreen> createState() =>
      _OnlineGameBoardScreenState();
}

class _OnlineGameBoardScreenState extends ConsumerState<OnlineGameBoardScreen> {
  bool _isAdvancingRound = false;
  bool _isLeavingInProgress = false;
  bool _finishedMarked = false;
  ActiveSessionNotifier? _activeSessionNotifier;
  RoomService? _roomService;

  Player get _myPlayer => widget.isHost ? Player.x : Player.o;

  @override
  void didUpdateWidget(covariant OnlineGameBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.code != widget.room.code) {
      _finishedMarked = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activeSessionNotifier = ref.read(activeSessionProvider.notifier);
        _roomService = ref.read(roomServiceProvider);
        _activeSessionNotifier?.setActiveSession(
          ActiveSession(
            roomCode: widget.room.code,
            isHost: widget.isHost,
            isInGame: true,
          ),
        );

        final auth = ref.read(authServiceProvider);
        final uid = auth.currentUid ??
            (widget.isHost ? widget.room.hostUid : (widget.room.guestUid ?? ''));

        if (widget.isHost) {
          _roomService?.registerHostInGameDisconnect(
            roomCode: widget.room.code,
            hostUid: uid,
          );
        } else {
          _roomService?.registerGuestInGameDisconnect(
            roomCode: widget.room.code,
            guestUid: uid,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    final notifier = _activeSessionNotifier;
    final code = widget.room.code;
    Future.microtask(() => notifier?.clear(code));
    _roomService?.cancelDisconnectHandlers(widget.room.code);
    super.dispose();
  }

  Future<void> _handleCellTap(
    Position pos,
    OnlineGameState gameState,
    bool isTerminated,
  ) async {
    if (isTerminated || gameState.status != OnlineGameStatus.playing) return;
    final isMyTurn = gameState.currentTurn == _myPlayer;
    if (!isMyTurn) return;

    final result = await ref.read(onlineMatchServiceProvider).submitMove(
          room: widget.room,
          position: pos,
          player: _myPlayer,
        );

    if (!mounted) return;

    if (result is SubmitMoveFailure) {
      final strings = ref.read(stringsProvider);
      switch (result.reason) {
        case SubmitMoveFailureReason.notYourTurn:
          // Benign race: opponent moved fast, turn swapped
          break;
        case SubmitMoveFailureReason.cellTaken:
          // Cell taken: re-enable board without placing phantom move
          break;
        case SubmitMoveFailureReason.gameMissing:
        case SubmitMoveFailureReason.notPlaying:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                strings.isArabic
                    ? 'انتهت الجلسة أو المباراة'
                    : 'Session or match ended',
                style: const TextStyle(color: NeonColors.textPrimary),
              ),
              backgroundColor: NeonColors.surface,
              duration: const Duration(seconds: 2),
            ),
          );
        case SubmitMoveFailureReason.transactionAborted:
          break;
      }
    }
  }

  Future<void> _handleNextRound(OnlineGameState currentState) async {
    if (_isAdvancingRound) return;
    setState(() => _isAdvancingRound = true);

    try {
      await ref.read(onlineMatchServiceProvider).advanceNextRound(
            room: widget.room,
            currentState: currentState,
          );
    } finally {
      if (mounted) {
        setState(() => _isAdvancingRound = false);
      }
    }
  }

  /// Handles rematch on the same room, resetting round, scores, and board.
  Future<void> _handleRematch(RoomModel currentRoom) async {
    if (_isAdvancingRound) return;

    setState(() => _isAdvancingRound = true);
    try {
      await ref.read(onlineMatchServiceProvider).rematch(
            room: currentRoom,
          );
      _finishedMarked = false;
    } catch (e) {
      if (mounted) {
        final strings = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isArabic ? 'فشل إعادة اللعب' : 'Failed to start rematch',
              style: const TextStyle(color: NeonColors.textPrimary),
            ),
            backgroundColor: NeonColors.surface,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdvancingRound = false);
      }
    }
  }

  /// Lets the host edit room settings and apply them to the same room without leaving.
  Future<void> _handleChangeSettings(RoomModel currentRoom) async {
    final strings = ref.read(stringsProvider);
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.onlyHostCanChangeSettings,
            style: const TextStyle(color: NeonColors.textPrimary),
          ),
          backgroundColor: NeonColors.surface,
        ),
      );
      return;
    }

    if (_isAdvancingRound) return;

    final newConfig = await showRoomSettingsSheet(
      context,
      initialConfig: currentRoom.config,
      isArabic: strings.isArabic,
    );

    if (newConfig == null || !mounted) return;

    setState(() => _isAdvancingRound = true);
    try {
      await ref.read(onlineMatchServiceProvider).rematch(
            room: currentRoom,
            newConfig: newConfig,
          );
      _finishedMarked = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isArabic ? 'فشل تحديث الإعدادات' : 'Failed to update settings',
              style: const TextStyle(color: NeonColors.textPrimary),
            ),
            backgroundColor: NeonColors.surface,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdvancingRound = false);
      }
    }
  }

  /// Prompts confirmation to end session and leave room.
  Future<void> _handleEndSession() async {
    final strings = ref.read(stringsProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NeonColors.dangerRed, width: 1.5),
        ),
        title: Text(
          strings.endSession,
          style: const TextStyle(
            color: NeonColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          strings.endSessionConfirm,
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
              strings.stayInRoom,
              style: const TextStyle(color: NeonColors.textSecondary),
            ),
          ),
          NeonButton(
            label: strings.endSession,
            color: NeonColors.dangerRed,
            isSolid: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _executeLeave();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  /// Handles leaving during an active match with confirmation and connection error handling.
  Future<bool> _confirmLeave(BuildContext context, {bool isMatchOver = false}) async {
    if (_isLeavingInProgress) return false;

    final strings = ref.read(stringsProvider);

    if (isMatchOver) {
      final shouldEnd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NeonColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NeonColors.dangerRed, width: 1.5),
          ),
          title: Text(
            strings.endSession,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            strings.endSessionConfirm,
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
                strings.stayInRoom,
                style: const TextStyle(color: NeonColors.textSecondary),
              ),
            ),
            NeonButton(
              label: strings.endSession,
              color: NeonColors.dangerRed,
              isSolid: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (shouldEnd != true || !mounted) return false;
      return _executeLeave();
    }

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
      final result = await ref.read(roomServiceProvider).leaveRoom(
            roomCode: widget.room.code,
            uid: uid,
            isHost: widget.isHost,
            isMatch: true,
          );

      if (result is LeaveRoomSuccess) {
        _isLeavingInProgress = false;
        ref.read(activeSessionProvider.notifier).clear(widget.room.code);
        return true;
      }

      if (!mounted) {
        _isLeavingInProgress = false;
        return true;
      }

      // If writing leave event failed due to connection error, show Retry / Leave Anyway / Cancel
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
        ref.read(activeSessionProvider.notifier).clear(widget.room.code);
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
    final gameAsync = ref.watch(onlineGameStreamProvider(widget.room.code));
    final roomAsync = ref.watch(roomStreamProvider(widget.room.code));
    final connectionStatus = ref.watch(connectionStatusProvider);

    final currentRoom = roomAsync.value;
    final currentGame = gameAsync.value;

    final resolved = resolveTermination(currentRoom, currentGame);
    final isTerminated = resolved.isTerminated;
    final hasNaturalMatchResult = currentGame != null &&
        currentGame.isMatchOver &&
        (currentGame.roundWinner != null ||
            currentGame.hostScore > 0 ||
            currentGame.guestScore > 0);

    // Fault-tolerant sync: if inferred terminated and not yet recorded on room, sync to RTDB
    if (resolved.isTerminated &&
        currentRoom != null &&
        currentRoom.termination == null &&
        currentRoom.status != RoomStatus.finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(roomServiceProvider).syncInferredTermination(
          roomCode: widget.room.code,
          termination: RoomTermination(
            reason: resolved.reason?.wireValue ?? 'guest_disconnected',
            byUid: resolved.byUid ?? '',
            byRole: resolved.byRole ?? (widget.isHost ? 'guest' : 'host'),
            message: resolved.getLocalizedMessage(strings, isHost: widget.isHost),
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      });
    }

    ref.listen<AsyncValue<OnlineGameState?>>(
      onlineGameStreamProvider(widget.room.code),
      (prev, next) {
        final game = next.value;
        if (game != null && game.isMatchOver && !_finishedMarked) {
          _finishedMarked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(roomServiceProvider).markMatchFinished(widget.room.code);
            }
          });
        }
        if (game != null && game.isPlaying && _finishedMarked) {
          _finishedMarked = false;
        }
      },
    );

    // Initial state trigger if screen loads while match is already over (idempotent via _finishedMarked)
    if (currentGame != null && currentGame.isMatchOver && !_finishedMarked) {
      _finishedMarked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(roomServiceProvider).markMatchFinished(widget.room.code);
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeave(
          context,
          isMatchOver: currentGame?.isMatchOver == true,
        );
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
            '${currentRoom?.config.boardSize ?? widget.room.config.boardSize}x${currentRoom?.config.boardSize ?? widget.room.config.boardSize} - ${widget.room.code}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsetsDirectional.only(end: 16),
              child: Center(child: ConnectionStatusBadge()),
            ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: NeonColors.cyanX),
            tooltip: strings.leaveRoom,
            onPressed: () async {
              final shouldLeave = await _confirmLeave(
                context,
                isMatchOver: currentGame?.isMatchOver == true,
              );
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Container(
          decoration: NeonColors.cyberBackground,
          child: SafeArea(
            child: Stack(
              children: [
                gameAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(NeonColors.cyanX),
                    ),
                  ),
                  error: (err, _) {
                    debugPrint('Connection error: $err');
                    return Center(
                      child: Text(
                        strings.connectionError,
                        style: const TextStyle(color: NeonColors.dangerRed),
                      ),
                    );
                  },
                  data: (gameState) {
                    if (gameState == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(NeonColors.cyanX),
                        ),
                      );
                    }

                    final boardConfig = BoardConfig(
                      rows: widget.room.config.boardSize,
                      cols: widget.room.config.boardSize,
                      winStreak: widget.room.config.winStreak,
                    );

                    // Reconstruct board from moves
                    var board = GameBoard.empty(boardConfig);
                    for (final m in gameState.moves) {
                      board = board.copyWithMove(m.position, m.player);
                    }

                    // Winning line reconstruction
                    final winningLine = (gameState.winningPositions != null &&
                            gameState.winningPositions!.isNotEmpty)
                        ? WinningLine(
                            positions: gameState.winningPositions!,
                            direction: WinDirection.horizontal,
                          )
                        : null;

                    final isMyTurn = gameState.currentTurn == _myPlayer &&
                        gameState.isPlaying &&
                        !isTerminated;

                    final myTurnColor = _myPlayer == Player.x
                        ? NeonColors.cyanX
                        : NeonColors.orangeO;

                    return Column(
                      children: [
                        // Temporary network reconnecting warning (distinct from intentional leave)
                        if (connectionStatus == ConnectionStatus.reconnecting &&
                            !isTerminated)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            color: NeonColors.amberGold.withValues(alpha: 0.2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      NeonColors.amberGold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  strings.connectionReconnecting,
                                  style: const TextStyle(
                                    color: NeonColors.amberGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Turn & Score HUD Card
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: NeonCard(
                            borderColor:
                                isMyTurn ? myTurnColor : NeonColors.borderSubtle,
                            hasGlow: isMyTurn,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Host (X) Score - Cyan identity
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: NeonColors.cyanX,
                                          width: 1.5,
                                        ),
                                        color: NeonColors.cyanX
                                            .withValues(alpha: 0.12),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'X',
                                          style: TextStyle(
                                            color: NeonColors.cyanX,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${gameState.hostScore}',
                                      style: const TextStyle(
                                        color: NeonColors.cyanX,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                // Round & Turn Indicator
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          strings.isArabic
                                              ? 'الجولة ${AppStrings.toArabicDigits(gameState.currentRound)}'
                                              : 'Round ${gameState.currentRound}',
                                          style: const TextStyle(
                                            color: NeonColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isMyTurn
                                                  ? myTurnColor
                                                      .withValues(alpha: 0.18)
                                                  : NeonColors.surfaceElevated,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isMyTurn
                                                    ? myTurnColor
                                                    : NeonColors.borderSubtle,
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Text(
                                              isMyTurn
                                                  ? (strings.isArabic
                                                      ? 'دورك العب الآن!'
                                                      : 'Your Turn!')
                                                  : (strings.isArabic
                                                      ? 'دور الخصم...'
                                                      : "Opponent's Turn..."),
                                              style: TextStyle(
                                                color: isMyTurn
                                                    ? myTurnColor
                                                    : NeonColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Guest (O) Score - Coral identity (orangeO)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${gameState.guestScore}',
                                      style: const TextStyle(
                                        color: NeonColors.orangeO,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: NeonColors.orangeO,
                                          width: 1.5,
                                        ),
                                        color: NeonColors.orangeO
                                            .withValues(alpha: 0.12),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'O',
                                          style: TextStyle(
                                            color: NeonColors.orangeO,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Game Board Grid
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: GameGridWidget(
                                config: boardConfig,
                                board: board,
                                winningLine: winningLine,
                                winner: gameState.roundWinner,
                                currentPlayer: gameState.currentTurn,
                                onCellTap: (pos) => _handleCellTap(
                                  pos,
                                  gameState,
                                  isTerminated,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Bottom Round End / Match End Banner
                        if ((gameState.isRoundOver || gameState.isMatchOver) &&
                            (!isTerminated || hasNaturalMatchResult))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: NeonColors.surface,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              border: Border.all(
                                color: gameState.isMatchOver
                                    ? NeonColors.amberGold
                                    : NeonColors.cyanX,
                                width: 1.5,
                              ),
                              boxShadow: NeonColors.glow(
                                color: gameState.isMatchOver
                                    ? NeonColors.amberGold
                                    : NeonColors.cyanX,
                                blur: 10,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  gameState.isMatchOver
                                      ? (gameState.roundWinner == null
                                          ? (strings.isArabic
                                              ? 'نهاية المباراة! تعادل'
                                              : 'Match Finished! Draw')
                                          : (strings.isArabic
                                              ? 'نهاية المباراة! الفائز: ${gameState.roundWinner!.symbol}'
                                              : 'Match Finished! Winner: ${gameState.roundWinner!.symbol}'))
                                      : (gameState.status ==
                                              OnlineGameStatus.roundDraw
                                          ? (strings.isArabic
                                              ? 'تعادل في هذه الجولة!'
                                              : 'Round Draw!')
                                          : (gameState.roundWinner == _myPlayer
                                              ? (strings.isArabic
                                                  ? 'أحسنت! فزت بالجولة'
                                                  : 'You won the round!')
                                              : (strings.isArabic
                                                  ? 'فاز الخصم بالجولة'
                                                  : 'Opponent won the round'))),
                                  style: TextStyle(
                                    color: gameState.isMatchOver
                                        ? NeonColors.amberGold
                                        : NeonColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (gameState.isMatchOver) ...[
                                  // 1. Rematch / Play Again Button
                                  NeonButton(
                                    label: _isAdvancingRound
                                        ? strings.connectionConnecting
                                        : strings.replayMatch,
                                    icon: Icons.replay_rounded,
                                    color: NeonColors.cyanX,
                                    isSolid: true,
                                    onPressed: _isAdvancingRound
                                        ? () {}
                                        : () => _handleRematch(currentRoom ?? widget.room),
                                  ),
                                  const SizedBox(height: 8),
                                  // 2. Change Settings Button (Host modifies on same room)
                                  NeonButton(
                                    label: strings.changeMatchSettings,
                                    icon: Icons.tune_rounded,
                                    color: NeonColors.amberGold,
                                    isSolid: false,
                                    onPressed: _isAdvancingRound
                                        ? () {}
                                        : () => _handleChangeSettings(currentRoom ?? widget.room),
                                  ),
                                  const SizedBox(height: 8),
                                  // 3. End Session Button
                                  NeonButton(
                                    label: strings.endSession,
                                    icon: Icons.logout_rounded,
                                    color: NeonColors.dangerRed,
                                    isSolid: false,
                                    onPressed: _isAdvancingRound
                                        ? () {}
                                        : _handleEndSession,
                                  ),
                                ] else if (widget.isHost)
                                  NeonButton(
                                    label: _isAdvancingRound
                                        ? strings.connectionConnecting
                                        : (strings.isArabic
                                            ? 'الجولة التالية'
                                            : 'Next Round'),
                                    color: NeonColors.cyanX,
                                    isSolid: true,
                                    onPressed: _isAdvancingRound
                                        ? () {}
                                        : () => _handleNextRound(gameState),
                                  )
                                else
                                  Text(
                                    strings.isArabic
                                        ? 'بانتظار المضيف لبدء الجولة التالية...'
                                        : 'Waiting for host to start next round...',
                                    style: const TextStyle(
                                      color: NeonColors.textSecondary,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // Termination / Leaving Overlay (shown only in the absence of a natural match completion)
                if (isTerminated && !hasNaturalMatchResult)
                  Container(
                    color: Colors.black.withValues(alpha: 0.85),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: NeonCard(
                        borderColor: NeonColors.dangerRed,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.exit_to_app_rounded,
                              color: NeonColors.dangerRed,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              resolved.getLocalizedMessage(
                                strings,
                                isHost: widget.isHost,
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: NeonColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (widget.isHost) ...[
                              NeonButton(
                                label: strings.returnToLobby,
                                color: NeonColors.cyanX,
                                isSolid: true,
                                onPressed: () async {
                                  await ref
                                      .read(roomServiceProvider)
                                      .reopenLobby(roomCode: widget.room.code);
                                  if (context.mounted) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => RoomLobbyScreen(
                                          roomCode: widget.room.code,
                                          isHost: true,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            NeonButton(
                              label: strings.isArabic
                                  ? 'العودة للرئيسية'
                                  : 'Return Home',
                              color: NeonColors.dangerRed,
                              isSolid: !widget.isHost,
                              onPressed: () async {
                                ref
                                    .read(activeSessionProvider.notifier)
                                    .clear(widget.room.code);
                                await ref
                                    .read(roomServiceProvider)
                                    .cancelDisconnectHandlers(widget.room.code);
                                if (context.mounted) {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
