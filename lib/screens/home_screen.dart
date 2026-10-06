import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_stats_provider.dart';
import '../providers/dummy_data.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/daily_goal_ring.dart';
import '../widgets/exercise_card.dart';
import '../widgets/shiny_rank_chip.dart';
import '../widgets/stat_chip.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final rank = ref.watch(myRankProvider).valueOrNull;
    final authUser = ref.watch(authProvider);
    final firestoreProfile = ref.watch(userProfileProvider).when(
      data: (UserProfile? value) => value,
      loading: () => null,
      error: (Object _, StackTrace _) => null,
    );
    final exercises = ref.watch(exercisesProvider);
    final isGuest = authUser?.isAnonymous ?? true;
    final fullName = firestoreProfile?.effectiveDisplayName ??
        (isGuest
            ? 'Guest Athlete'
            : (authUser?.displayName ?? 'Athlete'));
    final name = fullName.split(RegExp(r'\s+')).first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: UserAvatar(
                    radius: 26,
                    photoUrl: firestoreProfile?.photoUrl,
                    photoBase64: firestoreProfile?.customPhotoBase64,
                    avatarColorHex: firestoreProfile?.avatarColor,
                    initials: firestoreProfile?.initials ??
                        (isGuest
                            ? 'G'
                            : (fullName.trim().isEmpty
                            ? '?'
                            : fullName.trim()[0].toUpperCase())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                ShinyRankChip(
                  label: rank == null ? 'Unranked' : 'Rank #$rank',
                  shiny: rank != null,
                  onTap: () => context.go('/leaderboard'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                StatChip(
                  label: "Today's reps",
                  value: '${stats.todayReps}',
                  icon: Icons.flash_on_rounded,
                ),
                const SizedBox(width: 10),
                StatChip(
                  label: 'Streak',
                  value: '${stats.currentStreak}d',
                  icon: Icons.local_fire_department_rounded,
                ),
                const SizedBox(width: 10),
                StatChip(
                  label: 'This week',
                  value: '${stats.weekReps}',
                  icon: Icons.calendar_view_week_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            DailyGoalRing(todayReps: stats.todayReps),
            const SizedBox(height: 28),
            Text(
              'Today’s workout',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...exercises.take(1).map(
                  (e) => ExerciseCard(
                exercise: e,
                onStart: () => context.push('/exercise/${e.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}