import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../application/auth_service.dart';
import '../../application/room_service.dart';
import '../../domain/models/room_config.dart';
import 'room_lobby_screen.dart';

/// Screen allowing the host player to select match settings and create an online room.
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  int _selectedBoardSize = 3;
  int _selectedRoundsToWin = 1;
  bool _isCreating = false;

  final List<int> _boardSizes = const [3, 6, 9, 11];
  final List<int> _roundsOptions = const [1, 2, 3];

  Future<void> _handleCreateRoom() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.ensureSignedIn();
      final uid = user?.uid ?? auth.currentUid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';

      final roomService = ref.read(roomServiceProvider);
      final config = RoomConfig.forBoardSize(
        _selectedBoardSize,
        roundsToWin: _selectedRoundsToWin,
      );

      final room = await roomService.createRoom(
        config: config,
        hostUid: uid,
        hostName: 'Host ($uid)'.substring(0, 10),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RoomLobbyScreen(
              roomCode: room.code,
              isHost: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create room: $e'),
            backgroundColor: NeonColors.surface,
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

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          strings.createRoom,
          style: const TextStyle(
            color: NeonColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: NeonColors.cyanX),
      ),
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Board Size Selector Card
                NeonCard(
                  borderColor: NeonColors.borderSubtle,
                  hasGlow: false,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.boardSizeLabel,
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _boardSizes.map((size) {
                          final isSelected = _selectedBoardSize == size;
                          final label = switch (size) {
                            3 => strings.preset3x3,
                            6 => strings.preset6x6,
                            9 => strings.preset9x9,
                            11 => strings.preset11x11,
                            _ => '$size x $size',
                          };

                          return InkWell(
                            onTap: () => setState(() => _selectedBoardSize = size),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? NeonColors.cyanX.withValues(alpha: 0.16)
                                    : NeonColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? NeonColors.cyanX
                                      : NeonColors.borderSubtle,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? NeonColors.glow(color: NeonColors.cyanX, blur: 8)
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: NeonColors.cyanX,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? NeonColors.cyanX
                                          : NeonColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Rounds to Win Selector Card
                NeonCard(
                  borderColor: NeonColors.borderSubtle,
                  hasGlow: false,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.roundsToWinLabel,
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: _roundsOptions.map((rounds) {
                          final isSelected = _selectedRoundsToWin == rounds;
                          final label = rounds == 1
                              ? (strings.isArabic ? 'جولة واحدة' : '1 Round')
                              : (strings.isArabic
                                  ? 'أول من يفوز بـ ${AppStrings.toArabicDigits(rounds)}'
                                  : 'First to $rounds');

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _selectedRoundsToWin = rounds),
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? NeonColors.cyanX.withValues(alpha: 0.16)
                                        : NeonColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? NeonColors.cyanX
                                          : NeonColors.borderSubtle,
                                      width: isSelected ? 1.8 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? NeonColors.glow(
                                            color: NeonColors.cyanX,
                                            blur: 8,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 13,
                                          color: NeonColors.cyanX,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? NeonColors.cyanX
                                                  : NeonColors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
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
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Create Room Submit Button (Primary solid Cyan)
                NeonButton(
                  label: _isCreating ? strings.connectionConnecting : strings.createButton,
                  color: NeonColors.cyanX,
                  isSolid: true,
                  onPressed: _isCreating ? () {} : _handleCreateRoom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
