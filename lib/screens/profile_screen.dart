import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/dummy_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_chip.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final displayName = auth.isGuest ? 'Guest Athlete' : user.name;
    final join = _formatJoin(user.joinDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                child: Text(
                  auth.isGuest ? 'G' : user.initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
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
              StatChip(
                label: 'Workouts',
                value: '${user.totalWorkouts}',
                icon: Icons.fitness_center_rounded,
              ),
              const SizedBox(width: 10),
              StatChip(
                label: 'Total reps',
                value: '${user.totalReps}',
                icon: Icons.repeat_rounded,
              ),
              const SizedBox(width: 10),
              StatChip(
                label: 'Best streak',
                value: '${user.bestStreak}d',
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
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/auth');
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
