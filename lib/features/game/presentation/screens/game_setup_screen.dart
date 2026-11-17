import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/selectable_option_tile.dart';
import '../../../../core/widgets/sticky_bottom_bar.dart';
import '../../application/match_providers.dart';
import '../../domain/xo_engine.dart';
import 'game_board_screen.dart';

/// Screen allowing players to configure board size, match round count (1, 3, 5),
/// and chess-clock timer settings before launching a local match.
/// Updated for UX-CLARITY-02 with unified tokens, single selection pattern, and sticky CTA.
class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({super.key});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  bool _vsSystem = false;
  SystemDifficulty _systemDifficulty = SystemDifficulty.medium;
  Player _humanPlayer = Player.x;

  BoardConfig _selectedConfig = BoardConfig.grid3x3;
  int _selectedRounds = 3; // 1, 3 (default), 5
  TimerPreset _selectedTimerPreset = TimerPreset.none; // none (default)
  int _customTimerSeconds = 120; // 2 minutes default for custom

  String _getWinRuleText(int rounds, AppStrings strings) {
    final target = (rounds / 2).ceil();
    if (!strings.isArabic) {
      return rounds == 1 ? 'Winner: 1 of 1' : 'Winner: $target of $rounds rounds';
    }
    if (rounds == 1) return 'الفائز: ١ من ١';
    if (rounds == 3) return 'الفائز: ٢ من ٣ جولات';
    return 'الفائز: ٣ من ٥ جولات';
  }

  String _getSummaryText(AppStrings strings) {
    final board = '${AppStrings.toArabicDigits(_selectedConfig.rows)}×${AppStrings.toArabicDigits(_selectedConfig.cols)}';
    final rounds = _selectedRounds == 1
        ? (strings.isArabic ? 'جولة واحدة' : '1 Round')
        : (strings.isArabic ? '${AppStrings.toArabicDigits(_selectedRounds)} جولات' : '$_selectedRounds Rounds');
    final timer = switch (_selectedTimerPreset) {
      TimerPreset.none => strings.noTimer,
      TimerPreset.oneMinute => strings.oneMinutePerPlayer,
      TimerPreset.threeMinutes => strings.threeMinutesPerPlayer,
      TimerPreset.fiveMinutes => strings.fiveMinutesPerPlayer,
      TimerPreset.custom => strings.formatDuration(Duration(seconds: _customTimerSeconds)),
    };
    return '$board · $rounds · $timer';
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final presets = BoardConfig.authorizedPresets;

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        title: Text(
          strings.setupTitle,
          style: AppTokens.screenTitleStyle,
        ),
      ),
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppTokens.maxTabletContentWidth),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section 0: Game Mode (local two players vs the system)
                          Text(
                            strings.chooseMode,
                            style: AppTokens.sectionTitleStyle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableOptionTile(
                                  label: strings.modeLocalShort,
                                  isSelected: !_vsSystem,
                                  leading: const Icon(Icons.group_rounded, size: 18, color: AppTokens.cyan),
                                  onTap: () => setState(() => _vsSystem = false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableOptionTile(
                                  label: strings.modeSystem,
                                  isSelected: _vsSystem,
                                  leading: const Icon(Icons.smart_toy_rounded, size: 18, color: AppTokens.cyan),
                                  onTap: () => setState(() => _vsSystem = true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // System-only options (hidden for local play)
                          if (_vsSystem) ...[
                            Text(
                              strings.systemLevelTitle,
                              style: AppTokens.sectionTitleStyle,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableOptionTile(
                                    label: strings.difficultyEasy,
                                    isSelected: _systemDifficulty == SystemDifficulty.easy,
                                    onTap: () {
                                      setState(() => _systemDifficulty = SystemDifficulty.easy);
                                      ref.read(difficultyProgressionServiceProvider).setDifficulty(SystemDifficulty.easy);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SelectableOptionTile(
                                    label: strings.difficultyMedium,
                                    isSelected: _systemDifficulty == SystemDifficulty.medium,
                                    onTap: () {
                                      setState(() => _systemDifficulty = SystemDifficulty.medium);
                                      ref.read(difficultyProgressionServiceProvider).setDifficulty(SystemDifficulty.medium);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SelectableOptionTile(
                                    label: strings.difficultyHard,
                                    isSelected: _systemDifficulty == SystemDifficulty.hard,
                                    onTap: () {
                                      setState(() => _systemDifficulty = SystemDifficulty.hard);
                                      ref.read(difficultyProgressionServiceProvider).setDifficulty(SystemDifficulty.hard);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    strings.autoProgression,
                                    style: AppTokens.bodyStyle.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  Switch(
                                    value: ref.watch(difficultyProgressionServiceProvider).state.isAutoProgressionEnabled,
                                    activeThumbColor: AppTokens.cyan,
                                    onChanged: (val) {
                                      ref.read(difficultyProgressionServiceProvider).setAutoProgressionEnabled(val);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              strings.chooseYourMark,
                              style: AppTokens.sectionTitleStyle,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableOptionTile(
                                    label: strings.playAsX,
                                    isSelected: _humanPlayer == Player.x,
                                    leading: const Icon(Icons.close_rounded, size: 20, color: AppTokens.cyan),
                                    onTap: () => setState(() => _humanPlayer = Player.x),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableOptionTile(
                                    label: strings.playAsO,
                                    isSelected: _humanPlayer == Player.o,
                                    leading: const Icon(Icons.circle_outlined, size: 20, color: AppTokens.coral),
                                    onTap: () => setState(() => _humanPlayer = Player.o),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Section 1: Choose Grid Size (single row, dimensions only)
                          Text(
                            strings.chooseGrid,
                            style: AppTokens.sectionTitleStyle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: presets.map((config) {
                              final isSelected = _selectedConfig == config;
                              final dimension = '${config.rows}×${config.cols}';

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: SelectableOptionTile(
                                    key: ValueKey('grid-preset-$dimension'),
                                    label: dimension,
                                    isSelected: isSelected,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                                    onTap: () => setState(() => _selectedConfig = config),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Section 2: Choose Total Rounds (1, 3, 5 only)
                          Text(
                            strings.chooseRounds,
                            style: AppTokens.sectionTitleStyle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: MatchConfig.authorizedRoundCounts.map((count) {
                              final isSelected = _selectedRounds == count;
                              final label = count == 1
                                  ? strings.oneRound
                                  : (count == 3 ? (strings.isArabic ? '٣ جولات' : '3 Rounds') : (strings.isArabic ? '٥ جولات' : '5 Rounds'));

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: SelectableOptionTile(
                                    label: label,
                                    isSelected: isSelected,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    badge: count == 3
                                        ? Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppTokens.cyan.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              strings.isArabic ? 'افتراضي' : 'Default',
                                              style: TextStyle(
                                                color: isSelected ? AppTokens.cyan : AppTokens.textMuted,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        : null,
                                    onTap: () => setState(() => _selectedRounds = count),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _getWinRuleText(_selectedRounds, strings),
                              style: AppTokens.captionStyle.copyWith(color: AppTokens.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Section 3: Chess-Clock Timer Options
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  strings.timerOption,
                                  style: AppTokens.sectionTitleStyle,
                                ),
                              ),
                              if (_selectedTimerPreset != TimerPreset.none)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTokens.cyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTokens.cyan.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    strings.chessClockBadge,
                                    style: const TextStyle(
                                      color: AppTokens.cyan,
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
                              SelectableOptionTile(
                                label: strings.noTimer,
                                isSelected: _selectedTimerPreset == TimerPreset.none,
                                leading: const Icon(Icons.timer_off_outlined, size: 16, color: AppTokens.cyan),
                                onTap: () => setState(() => _selectedTimerPreset = TimerPreset.none),
                              ),
                              SelectableOptionTile(
                                label: strings.oneMinutePerPlayer,
                                isSelected: _selectedTimerPreset == TimerPreset.oneMinute,
                                leading: const Icon(Icons.timer_outlined, size: 16, color: AppTokens.cyan),
                                onTap: () => setState(() => _selectedTimerPreset = TimerPreset.oneMinute),
                              ),
                              SelectableOptionTile(
                                label: strings.threeMinutesPerPlayer,
                                isSelected: _selectedTimerPreset == TimerPreset.threeMinutes,
                                leading: const Icon(Icons.timer_outlined, size: 16, color: AppTokens.cyan),
                                onTap: () => setState(() => _selectedTimerPreset = TimerPreset.threeMinutes),
                              ),
                              SelectableOptionTile(
                                label: strings.fiveMinutesPerPlayer,
                                isSelected: _selectedTimerPreset == TimerPreset.fiveMinutes,
                                leading: const Icon(Icons.timer_outlined, size: 16, color: AppTokens.cyan),
                                onTap: () => setState(() => _selectedTimerPreset = TimerPreset.fiveMinutes),
                              ),
                              SelectableOptionTile(
                                label: strings.customTimer,
                                isSelected: _selectedTimerPreset == TimerPreset.custom,
                                leading: const Icon(Icons.tune_rounded, size: 16, color: AppTokens.cyan),
                                onTap: () => setState(() => _selectedTimerPreset = TimerPreset.custom),
                              ),
                            ],
                          ),

                          // Custom Timer Bounds & Stepper
                          if (_selectedTimerPreset == TimerPreset.custom) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTokens.surfaceElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTokens.cyan.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        strings.customTimerBounds(15, 900),
                                        style: AppTokens.captionStyle.copyWith(color: AppTokens.textSecondary),
                                      ),
                                      Text(
                                        strings.formatDuration(Duration(seconds: _customTimerSeconds)),
                                        style: const TextStyle(
                                          color: AppTokens.cyan,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppTokens.cyan,
                                      thumbColor: AppTokens.cyan,
                                      inactiveTrackColor: AppTokens.borderSubtle,
                                      overlayColor: AppTokens.cyan.withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value: _customTimerSeconds.toDouble(),
                                      min: 15,
                                      max: 900,
                                      divisions: (900 - 15) ~/ 15,
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
                        ],
                      ),
                    ),
                  ),

                  // Sticky Bottom Bar with live summary and Start Button
                  StickyBottomBar(
                    summaryText: _getSummaryText(strings),
                    child: NeonButton(
                      label: strings.startGame,
                      icon: Icons.play_arrow_rounded,
                      color: AppTokens.cyan,
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

                        ref.read(pendingMatchConfigProvider.notifier).select(matchConfig);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GameBoardScreen(),
                          ),
                        );
                      },
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
