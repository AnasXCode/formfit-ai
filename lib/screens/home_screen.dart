import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/dummy_data.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_card.dart';
import '../widgets/stat_chip.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(currentUserProvider);
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
            : (authUser?.displayName ?? stats.name));
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
                UserAvatar(
                  radius: 26,
                  photoUrl: firestoreProfile?.photoUrl,
                  avatarColorHex: firestoreProfile?.avatarColor,
                  initials: firestoreProfile?.initials ??
                      (isGuest ? 'G' : stats.initials),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Rank #${stats.rank}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
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
                  value: '${stats.weeklyTotal}',
                  icon: Icons.calendar_view_week_rounded,
                ),
              ],
            ),
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
            const SizedBox(height: 22),
            Text(
              'More exercises',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Locked for now — layout is ready.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ...exercises.skip(1).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExerciseCard(exercise: e),
                  ),
                ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pose detection will plug into the Push-Ups session next.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
