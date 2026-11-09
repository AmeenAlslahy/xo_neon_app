import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../../online/presentation/screens/online_lobby_entry_screen.dart';
import '../../../online/presentation/widgets/connection_status_badge.dart';
import '../../application/match_providers.dart';
import '../widgets/neon_o_widget.dart';
import '../widgets/neon_x_widget.dart';
import 'game_setup_screen.dart';

/// The main landing screen featuring glowing cyber-neon branding and mode
/// cards. Reads strings/locale directly from Riverpod (no prop drilling).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final soundEnabled = ref.watch(soundEffectsEnabledProvider);
    final reduceMotion = ref.watch(reducedMotionProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Quick Bar (Language & Accessibility controls)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Live Connection Indicator
                    const ConnectionStatusBadge(),

                    // Quick Action Buttons
                    Row(
                      children: [
                        // Sound Toggle Button
                        IconButton(
                          tooltip: strings.soundEffects,
                          icon: Icon(
                            soundEnabled ? Icons.volume_up : Icons.volume_off,
                            color: soundEnabled ? NeonColors.cyanX : NeonColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () =>
                              ref.read(soundEffectsEnabledProvider.notifier).toggle(),
                        ),

                        // Reduced Motion Toggle Button
                        IconButton(
                          tooltip: strings.reducedMotion,
                          icon: Icon(
                            reduceMotion ? Icons.motion_photos_off : Icons.motion_photos_on,
                            color: reduceMotion ? NeonColors.cyanX : NeonColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () =>
                              ref.read(reducedMotionProvider.notifier).toggle(),
                        ),

                        // Language Switcher (Primary action styling)
                        TextButton(
                          onPressed: () => ref.read(localeProvider.notifier).toggle(),
                          child: Text(
                            strings.languageToggle,
                            style: const TextStyle(
                              color: NeonColors.cyanX,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Neon Brand Header (Showcases X cyan & O coral identities)
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          NeonXWidget(size: 72),
                          SizedBox(width: 20),
                          NeonOWidget(size: 72),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        strings.appTitle,
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.appSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Mode 1: Local Play
                NeonCard(
                  borderColor: NeonColors.borderSubtle,
                  hasGlow: false,
                  padding: const EdgeInsets.all(20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GameSetupScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NeonColors.cyanX.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: NeonColors.cyanX, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.phone_android,
                          color: NeonColors.cyanX,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.modeLocal,
                              style: const TextStyle(
                                color: NeonColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.modeLocalDesc,
                              style: const TextStyle(
                                color: NeonColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: NeonColors.cyanX,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mode 2: Play with Friend (Online Multiplayer)
                // Unified Cyan interactive action identity (Coral reserved for Player O)
                NeonCard(
                  borderColor: NeonColors.borderSubtle,
                  hasGlow: false,
                  padding: const EdgeInsets.all(20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnlineLobbyEntryScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NeonColors.cyanX.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: NeonColors.cyanX, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.wifi_tethering,
                          color: NeonColors.cyanX,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.modeFriend,
                              style: const TextStyle(
                                color: NeonColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.modeFriendDesc,
                              style: const TextStyle(
                                color: NeonColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: NeonColors.cyanX,
                        size: 16,
                      ),
                    ],
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
