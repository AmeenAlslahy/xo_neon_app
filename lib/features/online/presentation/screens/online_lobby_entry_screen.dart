import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/neon_card.dart';
import '../widgets/connection_status_badge.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

/// Entry screen for online multiplayer, allowing the user to either host
/// a new room or join an existing one by code.
/// Updated for UX-CLARITY-02: single title, labeled connection status badge, vertically centered layout.
class OnlineLobbyEntryScreen extends ConsumerWidget {
  const OnlineLobbyEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          strings.onlineLobbyTitle,
          style: AppTokens.screenTitleStyle,
        ),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: ConnectionStatusBadge(showLabel: true),
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: AppTokens.cyan),
      ),
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppTokens.maxTabletContentWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon + Subtitle (No duplicate "العب أونلاين" title)
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTokens.surfaceElevated,
                              border: Border.all(
                                color: AppTokens.cyan,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.wifi_tethering_rounded,
                              color: AppTokens.cyan,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            strings.onlineLobbySubtitle,
                            textAlign: TextAlign.center,
                            style: AppTokens.bodyStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card 1: Create Room (Host)
                    NeonCard(
                      borderColor: AppTokens.borderSubtle,
                      hasGlow: false,
                      padding: const EdgeInsets.all(18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateRoomScreen(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTokens.cyan.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTokens.cyan, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppTokens.cyan,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.createRoom,
                                  style: AppTokens.cardTitleStyle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strings.createRoomDesc,
                                  style: AppTokens.bodyStyle,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppTokens.cyan,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 2: Join Room (Guest) - Neutral surface, subtle border, no coral
                    NeonCard(
                      borderColor: AppTokens.borderSubtle,
                      hasGlow: false,
                      padding: const EdgeInsets.all(18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JoinRoomScreen(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTokens.surfaceElevated,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTokens.borderSubtle,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.login_rounded,
                              color: AppTokens.cyan,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.joinRoom,
                                  style: AppTokens.cardTitleStyle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strings.joinRoomDesc,
                                  style: AppTokens.bodyStyle,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppTokens.cyan,
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
        ),
      ),
    );
  }
}
