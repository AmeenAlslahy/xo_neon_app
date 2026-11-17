import 'package:flutter/material.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/models/room_config.dart';

/// Opens the in-lobby editor that lets the host change the board size and
/// rounds-to-win before the match starts.
///
/// Returns the new [RoomConfig], or null when the host cancels.
Future<RoomConfig?> showRoomSettingsSheet(
  BuildContext context, {
  required RoomConfig initialConfig,
  required bool isArabic,
}) {
  return showModalBottomSheet<RoomConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoomSettingsSheet(
      initialConfig: initialConfig,
      isArabic: isArabic,
    ),
  );
}

class _RoomSettingsSheet extends StatefulWidget {
  const _RoomSettingsSheet({
    required this.initialConfig,
    required this.isArabic,
  });

  final RoomConfig initialConfig;
  final bool isArabic;

  @override
  State<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends State<_RoomSettingsSheet> {
  static const List<int> _boardSizes = [3, 6, 9, 11];
  static const List<int> _roundsOptions = [1, 2, 3];

  late int _boardSize = widget.initialConfig.boardSize;
  late int _roundsToWin = widget.initialConfig.roundsToWin;

  RoomConfig get _selectedConfig => RoomConfig.forBoardSize(
        _boardSize,
        roundsToWin: _roundsToWin,
      ).copyWith(turnTimeLimitSeconds: widget.initialConfig.turnTimeLimitSeconds);

  String _boardLabel(AppStrings strings, int size) => switch (size) {
        3 => strings.preset3x3,
        6 => strings.preset6x6,
        9 => strings.preset9x9,
        11 => strings.preset11x11,
        _ => '$size×$size',
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(isArabic: widget.isArabic);

    return Container(
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: NeonColors.borderSubtle, width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NeonColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: NeonColors.cyanX,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.roomSettingsTitle,
                      style: const TextStyle(
                        color: NeonColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: strings.cancelAction,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: NeonColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                strings.roomSettingsHint,
                style: const TextStyle(
                  color: NeonColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Board size
              Text(
                strings.boardSizeLabel,
                style: const TextStyle(
                  color: NeonColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _boardSizes.map((size) {
                  return _SettingsChoice(
                    key: ValueKey('room-settings-board-$size'),
                    label: _boardLabel(strings, size),
                    isSelected: _boardSize == size,
                    onTap: () => setState(() => _boardSize = size),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Rounds to win
              Text(
                strings.roundsToWinLabel,
                style: const TextStyle(
                  color: NeonColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _roundsOptions.map((rounds) {
                  return _SettingsChoice(
                    key: ValueKey('room-settings-rounds-$rounds'),
                    label: strings.roundsToWinOption(rounds),
                    isSelected: _roundsToWin == rounds,
                    onTap: () => setState(() => _roundsToWin = rounds),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      label: strings.cancelAction,
                      isSecondary: true,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeonButton(
                      label: strings.saveChanges,
                      color: NeonColors.cyanX,
                      isSolid: true,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onPressed: () =>
                          Navigator.of(context).pop(_selectedConfig),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsChoice extends StatelessWidget {
  const _SettingsChoice({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? NeonColors.cyanX.withValues(alpha: 0.16)
                : NeonColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? NeonColors.cyanX : NeonColors.borderSubtle,
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
                  size: 15,
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
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
