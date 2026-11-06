import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/neon_card.dart';
import '../widgets/neon_o_widget.dart';
import '../widgets/neon_x_widget.dart';
import 'game_setup_screen.dart';

/// The main landing screen featuring glowing cyber-neon branding and mode cards.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onToggleLanguage;
  final bool isArabic;

  const HomeScreen({
    super.key,
    this.onToggleLanguage,
    this.isArabic = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _soundEnabled = true;
  bool _reduceMotionPreview = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(isArabic: widget.isArabic);

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
                  // App Title Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: NeonColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NeonColors.borderSubtle),
                    ),
                    child: Text(
                      strings.appTitle,
                      style: const TextStyle(
                        color: NeonColors.cyanX,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  // Quick Action Buttons
                  Row(
                    children: [
                      // Sound Toggle Preview
                      IconButton(
                        tooltip: strings.soundEffects,
                        icon: Icon(
                          _soundEnabled ? Icons.volume_up : Icons.volume_off,
                          color: _soundEnabled ? NeonColors.cyanX : NeonColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
                      ),

                      // Reduced Motion Toggle Preview
                      IconButton(
                        tooltip: strings.reducedMotion,
                        icon: Icon(
                          _reduceMotionPreview ? Icons.motion_photos_off : Icons.motion_photos_on,
                          color: _reduceMotionPreview ? NeonColors.amberGold : NeonColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _reduceMotionPreview = !_reduceMotionPreview),
                      ),

                      // Language Switcher
                      TextButton(
                        onPressed: widget.onToggleLanguage,
                        child: Text(
                          strings.languageToggle,
                          style: const TextStyle(
                            color: NeonColors.magentaO,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Neon Brand Header
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

              // Mode 1: Local Play (Active in V1)
              NeonCard(
                borderColor: NeonColors.cyanX,
                hasGlow: true,
                padding: const EdgeInsets.all(20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GameSetupScreen(isArabic: widget.isArabic),
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
                        boxShadow: NeonColors.glow(color: NeonColors.cyanX, blur: 8),
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

              // Mode 2: Play with Friend (Online - Clearly indicated as Coming Soon)
              NeonCard(
                borderColor: NeonColors.borderSubtle,
                hasGlow: false,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NeonColors.magentaO.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: NeonColors.textMuted, width: 1.0),
                      ),
                      child: const Icon(
                        Icons.wifi_tethering,
                        color: NeonColors.textMuted,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                strings.modeFriend,
                                style: const TextStyle(
                                  color: NeonColors.textSecondary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.modeFriendDesc,
                            style: const TextStyle(
                              color: NeonColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Coming soon badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: NeonColors.amberGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: NeonColors.amberGold, width: 0.8),
                            ),
                            child: Text(
                              strings.comingSoonBadge,
                              style: const TextStyle(
                                color: NeonColors.amberGold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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

