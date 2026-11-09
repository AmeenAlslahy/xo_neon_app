import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_card.dart';
import '../widgets/connection_status_badge.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

/// Entry screen for online multiplayer, allowing the user to either host
/// a new room or join an existing one by code.
class OnlineLobbyEntryScreen extends ConsumerWidget {
  const OnlineLobbyEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          strings.onlineLobbyTitle,
          style: const TextStyle(
            color: NeonColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 16),
            child: Center(child: ConnectionStatusBadge()),
          ),
        ],
        iconTheme: const IconThemeData(color: NeonColors.cyanX),
      ),
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Subtitle
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: NeonColors.surfaceElevated,
                          border: Border.all(
                            color: NeonColors.cyanX,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.wifi_tethering_rounded,
                          color: NeonColors.cyanX,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.onlineLobbyTitle,
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.onlineLobbySubtitle,
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

                // Card 1: Create Room (Host)
                NeonCard(
                  borderColor: NeonColors.borderSubtle,
                  hasGlow: false,
                  padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NeonColors.cyanX.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: NeonColors.cyanX, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.add_circle_outline_rounded,
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
                              strings.createRoom,
                              style: const TextStyle(
                                color: NeonColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.createRoomDesc,
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

                // Card 2: Join Room (Guest) - Unified with Cyan action identity
                NeonCard(
                  borderColor: NeonColors.borderSubtle,
                  hasGlow: false,
                  padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NeonColors.cyanX.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NeonColors.cyanX,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.login_rounded,
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
                              strings.joinRoom,
                              style: const TextStyle(
                                color: NeonColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.joinRoomDesc,
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
