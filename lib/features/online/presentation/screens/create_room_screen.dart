import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/selectable_option_tile.dart';
import '../../../../core/widgets/sticky_bottom_bar.dart';
import '../../application/auth_service.dart';
import '../../application/room_service.dart';
import '../../domain/models/room_config.dart';
import 'room_lobby_screen.dart';

/// Screen allowing the host player to select match settings and create an online room.
/// Updated for UX-CLARITY-02 with balanced 2x2 grid, computed win rules, and sticky CTA.
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  int _selectedBoardSize = 3;
  int _selectedRoundsToWin = 1;
  bool _isCreating = false;

  final List<int> _roundsOptions = const [1, 2, 3];

  String _formatRoundOption(int rounds, AppStrings strings) {
    if (!strings.isArabic) {
      return switch (rounds) {
        1 => 'Winner: 1 of 1',
        2 => 'Winner: 2 of 3',
        3 => 'Winner: 3 of 5',
        _ => 'First to $rounds',
      };
    }
    return switch (rounds) {
      1 => 'الفائز: ١ من ١',
      2 => 'الفائز: ٢ من ٣ جولات',
      3 => 'الفائز: ٣ من ٥ جولات',
      _ => 'أول من يفوز بـ ${AppStrings.toArabicDigits(rounds)}',
    };
  }

  String _getSummaryText(AppStrings strings) {
    final board =
        '${AppStrings.toArabicDigits(_selectedBoardSize)}×${AppStrings.toArabicDigits(_selectedBoardSize)}';
    final rounds = _formatRoundOption(_selectedRoundsToWin, strings);
    return '$board · $rounds · ${strings.noTimer}';
  }

  Future<void> _handleCreateRoom() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.ensureSignedIn();
      final uid = user?.uid ?? auth.currentUid;
      if (uid == null || uid.isEmpty) {
        if (mounted) {
          final strings = ref.read(stringsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.authFailed),
              backgroundColor: NeonColors.dangerRed,
            ),
          );
        }
        return;
      }
      final shortUid = uid.length > 4 ? uid.substring(uid.length - 4) : uid;

      final roomService = ref.read(roomServiceProvider);
      final config = RoomConfig.forBoardSize(
        _selectedBoardSize,
        roundsToWin: _selectedRoundsToWin,
      );

      final room = await roomService.createRoom(
        config: config,
        hostUid: uid,
        hostName: 'Host ($shortUid)',
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RoomLobbyScreen(roomCode: room.code, isHost: true),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to create room: $e');
      if (mounted) {
        final strings = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.failedToCreateRoom),
            backgroundColor: AppTokens.surface,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final currentConfig = RoomConfig.forBoardSize(_selectedBoardSize);
    final winStreak = currentConfig.winStreak;

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(strings.createRoom, style: AppTokens.screenTitleStyle),
        iconTheme: const IconThemeData(color: AppTokens.cyan),
      ),
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppTokens.maxTabletContentWidth,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section 1: Board Size (Balanced 2x2 grid)
                          Text(
                            strings.boardSizeLabel,
                            style: AppTokens.sectionTitleStyle,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableOptionTile(
                                  label: '3×3',
                                  isSelected: _selectedBoardSize == 3,
                                  onTap: () =>
                                      setState(() => _selectedBoardSize = 3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableOptionTile(
                                  label: '6×6',
                                  isSelected: _selectedBoardSize == 6,
                                  onTap: () =>
                                      setState(() => _selectedBoardSize = 6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableOptionTile(
                                  label: '9×9',
                                  isSelected: _selectedBoardSize == 9,
                                  onTap: () =>
                                      setState(() => _selectedBoardSize = 9),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableOptionTile(
                                  label: '11×11',
                                  isSelected: _selectedBoardSize == 11,
                                  onTap: () =>
                                      setState(() => _selectedBoardSize = 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              strings.isArabic
                                  ? 'لوحة ${AppStrings.toArabicDigits(_selectedBoardSize)}×${AppStrings.toArabicDigits(_selectedBoardSize)} · ${AppStrings.toArabicDigits(winStreak)} على التوالي'
                                  : 'Board ${_selectedBoardSize}x$_selectedBoardSize · $winStreak in a row',
                              style: AppTokens.captionStyle.copyWith(
                                color: AppTokens.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section 2: Rounds to Win
                          Text(
                            strings.roundsToWinLabel,
                            style: AppTokens.sectionTitleStyle,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _roundsOptions.map((rounds) {
                              final isSelected = _selectedRoundsToWin == rounds;
                              final label = _formatRoundOption(rounds, strings);

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: SelectableOptionTile(
                                    label: label,
                                    isSelected: isSelected,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 2,
                                    ),
                                    onTap: () => setState(
                                      () => _selectedRoundsToWin = rounds,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pinned Sticky CTA
                  StickyBottomBar(
                    summaryText: _getSummaryText(strings),
                    child: NeonButton(
                      label: _isCreating
                          ? strings.connectionConnecting
                          : strings.createButton,
                      color: AppTokens.cyan,
                      isSolid: true,
                      isDisabled: _isCreating,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      onPressed: _isCreating ? null : _handleCreateRoom,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
