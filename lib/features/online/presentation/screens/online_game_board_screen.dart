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
import '../../application/auth_service.dart';
import '../../application/online_match_service.dart';
import '../../application/room_service.dart';
import '../../domain/models/online_game_state.dart';
import '../../domain/models/room_model.dart';

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

  Player get _myPlayer => widget.isHost ? Player.x : Player.o;

  Future<void> _handleCellTap(Position pos, OnlineGameState gameState) async {
    final isMyTurn = gameState.currentTurn == _myPlayer && gameState.isPlaying;
    if (!isMyTurn) return;

    await ref.read(onlineMatchServiceProvider).submitMove(
          room: widget.room,
          position: pos,
          player: _myPlayer,
        );
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
            roomCode: widget.room.code,
            uid: uid,
          );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final gameAsync = ref.watch(onlineGameStreamProvider(widget.room.code));

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
            '${widget.room.config.boardSize}x${widget.room.config.boardSize} - ${widget.room.code}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: NeonColors.cyanX),
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
            child: gameAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NeonColors.cyanX),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Connection error: $err',
                  style: const TextStyle(color: NeonColors.dangerRed),
                ),
              ),
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

                final isMyTurn =
                    gameState.currentTurn == _myPlayer && gameState.isPlaying;

                final myTurnColor =
                    _myPlayer == Player.x ? NeonColors.cyanX : NeonColors.orangeO;

                return Column(
                  children: [
                    // Turn & Score HUD Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: NeonCard(
                        borderColor: isMyTurn ? myTurnColor : NeonColors.borderSubtle,
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
                                    color:
                                        NeonColors.cyanX.withValues(alpha: 0.12),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMyTurn
                                              ? myTurnColor.withValues(alpha: 0.18)
                                              : NeonColors.surfaceElevated,
                                          borderRadius: BorderRadius.circular(12),
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
                            onCellTap: (pos) => _handleCellTap(pos, gameState),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Round End / Match End Banner
                    if (gameState.isRoundOver || gameState.isMatchOver)
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
                                  ? (strings.isArabic
                                      ? 'نهاية المباراة! الفائز: ${gameState.roundWinner?.symbol ?? ""}'
                                      : 'Match Finished! Winner: ${gameState.roundWinner?.symbol ?? ""}')
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
                            const SizedBox(height: 12),
                            if (gameState.isMatchOver)
                              NeonButton(
                                label: strings.isArabic
                                    ? 'العودة للرئيسية'
                                    : 'Return Home',
                                color: NeonColors.cyanX,
                                isSolid: true,
                                onPressed: () => Navigator.of(context).pop(),
                              )
                            else if (widget.isHost)
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
          ),
        ),
      ),
    );
  }
}
