import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../application/match_providers.dart';
import '../../domain/xo_engine.dart';
import 'game_board_screen.dart';

/// Screen allowing players to configure board size, match round count (1, 3, 5),
/// and chess-clock timer settings before launching a local match.
class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({super.key});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  late BoardConfig _selectedConfig;
  int _selectedRounds = 3; // 1, 3 (default), 5
  TimerPreset _selectedTimerPreset = TimerPreset.none; // none (default)
  int _customTimerSeconds = 120; // 2 minutes default for custom
  bool _vsSystem = false; // false = local two players (default)
  Player _humanPlayer = Player.x; // the system plays the other mark
  SystemDifficulty _systemDifficulty = SystemDifficulty.medium;

  @override
  void initState() {
    super.initState();
    _selectedConfig = BoardConfig.grid3x3;
    final progression = ref.read(difficultyProgressionServiceProvider);
    _systemDifficulty = progression.state.currentDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final presets = BoardConfig.authorizedPresets;

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: Text(strings.setupTitle),
      ),
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 0: Game Mode (local two players vs the system)
                Text(
                  strings.chooseMode,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildChoiceBox(
                      selected: !_vsSystem,
                      label: strings.modeLocalShort,
                      icon: Icons.group_rounded,
                      onTap: () => setState(() => _vsSystem = false),
                    ),
                    _buildChoiceBox(
                      selected: _vsSystem,
                      label: strings.modeSystem,
                      icon: Icons.smart_toy_rounded,
                      onTap: () => setState(() => _vsSystem = true),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // System-only options (hidden for local play)
                if (_vsSystem) ...[
                  Text(
                    strings.systemLevelTitle,
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildChoiceBox(
                        selected: _systemDifficulty == SystemDifficulty.easy,
                        label: strings.difficultyEasy,
                        icon: Icons.sentiment_satisfied_rounded,
                        onTap: () {
                          setState(
                              () => _systemDifficulty = SystemDifficulty.easy);
                          ref
                              .read(difficultyProgressionServiceProvider)
                              .setDifficulty(SystemDifficulty.easy);
                        },
                      ),
                      _buildChoiceBox(
                        selected: _systemDifficulty == SystemDifficulty.medium,
                        label: strings.difficultyMedium,
                        icon: Icons.sentiment_neutral_rounded,
                        onTap: () {
                          setState(
                              () => _systemDifficulty = SystemDifficulty.medium);
                          ref
                              .read(difficultyProgressionServiceProvider)
                              .setDifficulty(SystemDifficulty.medium);
                        },
                      ),
                      _buildChoiceBox(
                        selected: _systemDifficulty == SystemDifficulty.hard,
                        label: strings.difficultyHard,
                        icon: Icons.sentiment_very_dissatisfied_rounded,
                        onTap: () {
                          setState(
                              () => _systemDifficulty = SystemDifficulty.hard);
                          ref
                              .read(difficultyProgressionServiceProvider)
                              .setDifficulty(SystemDifficulty.hard);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.autoProgression,
                          style: const TextStyle(
                            color: NeonColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch(
                          value: ref
                              .watch(difficultyProgressionServiceProvider)
                              .state
                              .isAutoProgressionEnabled,
                          activeThumbColor: NeonColors.cyanX,
                          onChanged: (val) {
                            ref
                                .read(difficultyProgressionServiceProvider)
                                .setAutoProgressionEnabled(val);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.chooseYourMark,
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildChoiceBox(
                        selected: _humanPlayer == Player.x,
                        label: strings.playAsX,
                        icon: Icons.close,
                        iconColor: NeonColors.cyanX,
                        onTap: () =>
                            setState(() => _humanPlayer = Player.x),
                      ),
                      _buildChoiceBox(
                        selected: _humanPlayer == Player.o,
                        label: strings.playAsO,
                        icon: Icons.radio_button_unchecked,
                        iconColor: NeonColors.orangeO,
                        onTap: () =>
                            setState(() => _humanPlayer = Player.o),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                // Section 1: Choose Grid Size
                Text(
                  strings.chooseGrid,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...presets.map((config) {
                  final isSelected = _selectedConfig == config;
                  final title = strings.presetTitle(config);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NeonCard(
                      borderColor: isSelected ? NeonColors.cyanX : NeonColors.borderSubtle,
                      hasGlow: isSelected,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => setState(() => _selectedConfig = config),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? NeonColors.cyanX : NeonColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: isSelected
                                        ? NeonColors.textPrimary
                                        : NeonColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${strings.winCondition} ${strings.marksInRow(config.winStreak)}',
                                  style: TextStyle(
                                    color: isSelected ? NeonColors.cyanX : NeonColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? NeonColors.cyanX.withValues(alpha: 0.15)
                                  : NeonColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? NeonColors.cyanX : NeonColors.borderSubtle,
                              ),
                            ),
                            child: Text(
                              '${config.rows}×${config.cols}',
                              style: TextStyle(
                                color: isSelected ? NeonColors.cyanX : NeonColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 18),

                // Section 2: Choose Total Rounds (1, 3, 5)
                Text(
                  strings.chooseRounds,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: MatchConfig.authorizedRoundCounts.map((count) {
                    final isSelected = _selectedRounds == count;
                    final label = count == 1
                        ? strings.oneRound
                        : (count == 3 ? strings.threeRounds : strings.fiveRounds);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRounds = count),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? NeonColors.cyanX.withValues(alpha: 0.14)
                                  : NeonColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? NeonColors.cyanX : NeonColors.borderSubtle,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? NeonColors.glow(color: NeonColors.cyanX, blur: 8)
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppStrings.toArabicDigits(count),
                                      style: TextStyle(
                                        color: isSelected ? NeonColors.textPrimary : NeonColors.textSecondary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: NeonColors.cyanX,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? NeonColors.cyanX
                                          : NeonColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                const SizedBox(height: 18),

                // Section 3: Chess-Clock Timer Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.timerOption,
                      style: const TextStyle(
                        color: NeonColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedTimerPreset != TimerPreset.none)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: NeonColors.cyanX.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeonColors.cyanX.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          strings.chessClockBadge,
                          style: const TextStyle(
                            color: NeonColors.cyanX,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Timer Preset Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTimerOption(
                      preset: TimerPreset.none,
                      title: strings.noTimer,
                      icon: Icons.timer_off_outlined,
                    ),
                    _buildTimerOption(
                      preset: TimerPreset.oneMinute,
                      title: strings.oneMinutePerPlayer,
                      icon: Icons.timer_outlined,
                    ),
                    _buildTimerOption(
                      preset: TimerPreset.threeMinutes,
                      title: strings.threeMinutesPerPlayer,
                      icon: Icons.timer_outlined,
                    ),
                    _buildTimerOption(
                      preset: TimerPreset.fiveMinutes,
                      title: strings.fiveMinutesPerPlayer,
                      icon: Icons.timer_outlined,
                    ),
                    _buildTimerOption(
                      preset: TimerPreset.custom,
                      title: strings.customTimer,
                      icon: Icons.tune_rounded,
                    ),
                  ],
                ),

                // Custom Timer Bounds & Stepper
                if (_selectedTimerPreset == TimerPreset.custom) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: NeonColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NeonColors.cyanX.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              strings.customTimerBounds(15, 900),
                              style: const TextStyle(
                                color: NeonColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              strings.formatDuration(Duration(seconds: _customTimerSeconds)),
                              style: const TextStyle(
                                color: NeonColors.cyanX,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: NeonColors.cyanX,
                            thumbColor: NeonColors.cyanX,
                            inactiveTrackColor: NeonColors.borderSubtle,
                            overlayColor: NeonColors.cyanX.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _customTimerSeconds.toDouble(),
                            min: 15,
                            max: 900,
                            divisions: (900 - 15) ~/ 15, // 15s steps
                            onChanged: (val) {
                              setState(() {
                                _customTimerSeconds = val.round();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Launch Match Button
                NeonButton(
                  label: strings.startGame,
                  icon: Icons.play_arrow_rounded,
                  color: NeonColors.cyanX,
                  isSolid: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  onPressed: () {
                    final timerConfig = TimerConfig.fromPreset(
                      _selectedTimerPreset,
                      customDuration: Duration(seconds: _customTimerSeconds),
                    );

                    final matchConfig = MatchConfig(
                      boardConfig: _selectedConfig,
                      totalRounds: _selectedRounds,
                      timerConfig: timerConfig,
                      vsSystem: _vsSystem,
                      humanPlayer: _humanPlayer,
                      systemDifficulty: _systemDifficulty,
                    );

                    // Publish the configuration for the board screen, then navigate.
                    ref.read(pendingMatchConfigProvider.notifier).select(matchConfig);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GameBoardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable neon choice box (mode / system level / player mark rows).
  Widget _buildChoiceBox({
    required bool selected,
    required String label,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    const selectionColor = NeonColors.cyanX;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: selected
                  ? selectionColor.withValues(alpha: 0.16)
                  : NeonColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? selectionColor : NeonColors.borderSubtle,
                width: selected ? 1.8 : 1.0,
              ),
              boxShadow: selected
                  ? NeonColors.glow(color: selectionColor, blur: 8)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: iconColor ?? (selected ? selectionColor : NeonColors.textSecondary),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: NeonColors.cyanX,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? NeonColors.textPrimary : NeonColors.textSecondary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildTimerOption({
    required TimerPreset preset,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedTimerPreset == preset;

    return GestureDetector(
      onTap: () => setState(() => _selectedTimerPreset = preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? NeonColors.cyanX.withValues(alpha: 0.16)
              : NeonColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
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
                size: 14,
                color: NeonColors.cyanX,
              ),
              const SizedBox(width: 6),
            ] else ...[
              Icon(
                icon,
                size: 15,
                color: NeonColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                color: isSelected ? NeonColors.cyanX : NeonColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
