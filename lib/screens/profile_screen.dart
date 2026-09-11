import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/dummy_data.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_chip.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(currentUserProvider);
    final authUser = ref.watch(authProvider);
    final firestoreProfile = ref.watch(userProfileProvider).when(
          data: (UserProfile? value) => value,
          loading: () => null,
          error: (Object _, StackTrace _) => null,
        );
    final scheme = Theme.of(context).colorScheme;
    final isGuest = authUser?.isAnonymous ?? true;
    final displayName = isGuest
        ? 'Guest Athlete'
        : (authUser?.displayName ??
            firestoreProfile?.displayName ??
            stats.name);
    final joinDate = firestoreProfile?.createdAt.toDate() ?? stats.joinDate;
    final join = _formatJoin(joinDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Column(
            children: [
              UserAvatar(
                radius: 44,
                fontSize: 28,
                photoUrl: firestoreProfile?.photoUrl,
                initials: firestoreProfile?.initials ??
                    (isGuest ? 'G' : stats.initials),
              ),
              const SizedBox(height: 14),
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Joined $join',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // TODO: replace with real sessions data
              StatChip(
                label: 'Workouts',
                value: '${stats.totalWorkouts}',
                icon: Icons.fitness_center_rounded,
              ),
              const SizedBox(width: 10),
              // TODO: replace with real sessions data
              StatChip(
                label: 'Total reps',
                value: '${stats.totalReps}',
                icon: Icons.repeat_rounded,
              ),
              const SizedBox(width: 10),
              // TODO: replace with real sessions data
              StatChip(
                label: 'Best streak',
                value: '${stats.bestStreak}d',
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'UI only',
                onTap: () => _toast(context, 'Notifications coming later'),
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.5)),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'FormFit AI · 1.0.0',
                onTap: () => _showAbout(context),
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.5)),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Return to sign-in',
                destructive: true,
                onTap: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/auth');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatJoin(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About FormFit AI'),
        content: const Text(
          'AI pose-tracked fitness competitions. This build is UI-only: navigation, theme, and dummy data for review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
      ),
      onTap: onTap,
    );
  }
}
