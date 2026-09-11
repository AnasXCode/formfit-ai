import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class LeaderboardTile extends StatelessWidget {
  const LeaderboardTile({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = entry.rank <= 3;
    final highlight = entry.isCurrentUser;

    Color? badgeColor;
    IconData? badgeIcon;
    switch (entry.rank) {
      case 1:
        badgeColor = AppColors.gold;
        badgeIcon = Icons.emoji_events_rounded;
      case 2:
        badgeColor = AppColors.silver;
        badgeIcon = Icons.emoji_events_rounded;
      case 3:
        badgeColor = AppColors.bronze;
        badgeIcon = Icons.emoji_events_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outline.withValues(alpha: 0.7),
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: top
                ? Icon(badgeIcon, color: badgeColor, size: 26)
                : Text(
                    '${entry.rank}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: highlight
                ? scheme.primary.withValues(alpha: 0.22)
                : scheme.surfaceContainerHighest,
            child: Text(
              entry.initials,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (highlight) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${entry.reps}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 4),
          Text('reps', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
