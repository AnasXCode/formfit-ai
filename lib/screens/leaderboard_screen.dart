import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/leaderboard_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authProvider)?.isAnonymous ?? true;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'This Week'),
              Tab(text: 'All Time'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (isGuest) const _GuestLeaderboardHint(),
            Expanded(
              child: TabBarView(
                children: [
                  _BoardList(asyncEntries: ref.watch(weeklyLeaderboardProvider)),
                  _BoardList(
                    asyncEntries: ref.watch(allTimeLeaderboardProvider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestLeaderboardHint extends StatelessWidget {
  const _GuestLeaderboardHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: AppColors.accent.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () => context.go('/profile'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(Icons.link_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Link your Google account to join the leaderboard',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardList extends StatelessWidget {
  const _BoardList({required this.asyncEntries});

  final AsyncValue<List<LeaderboardEntry>> asyncEntries;

  @override
  Widget build(BuildContext context) {
    return asyncEntries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load leaderboard',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.leaderboard_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No data yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Complete a workout to appear on the leaderboard.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) => LeaderboardTile(entry: entries[i]),
        );
      },
    );
  }
}
