import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';

/// Card showing a player slot (Host or Guest) in an online match lobby.
class PlayerSlotCard extends StatelessWidget {
  const PlayerSlotCard({
    super.key,
    required this.roleTitle,
    required this.isHost,
    required this.playerName,
    required this.isOccupied,
    required this.isCurrentPlayer,
    required this.waitingText,
    required this.youBadgeText,
  });

  final String roleTitle;
  final bool isHost;
  final String? playerName;
  final bool isOccupied;
  final bool isCurrentPlayer;
  final String waitingText;
  final String youBadgeText;

  @override
  Widget build(BuildContext context) {
    final themeColor = isHost ? NeonColors.cyanX : NeonColors.orangeO;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOccupied ? themeColor : NeonColors.borderSubtle,
          width: isOccupied ? 1.5 : 1.0,
        ),
        boxShadow: isOccupied
            ? NeonColors.glow(color: themeColor, blur: 8)
            : null,
      ),
      child: Row(
        children: [
          // Icon badge (X or O)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOccupied
                  ? themeColor.withValues(alpha: 0.15)
                  : NeonColors.background,
              border: Border.all(
                color: isOccupied ? themeColor : NeonColors.borderSubtle,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                isHost ? 'X' : 'O',
                style: TextStyle(
                  color: isOccupied ? themeColor : NeonColors.textSecondary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Player name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      roleTitle,
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCurrentPlayer) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NeonColors.amberGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: NeonColors.amberGold,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          youBadgeText,
                          style: const TextStyle(
                            color: NeonColors.amberGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isOccupied ? (playerName ?? '') : waitingText,
                  textDirection: isOccupied ? TextDirection.ltr : null,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOccupied
                        ? NeonColors.textPrimary
                        : NeonColors.textSecondary,
                    fontSize: 15,
                    fontWeight:
                        isOccupied ? FontWeight.bold : FontWeight.normal,
                    fontStyle:
                        isOccupied ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Status icon
          if (isOccupied)
            Icon(
              Icons.check_circle_rounded,
              color: themeColor,
              size: 22,
            )
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(NeonColors.cyanX),
              ),
            ),
        ],
      ),
    );
  }
}
