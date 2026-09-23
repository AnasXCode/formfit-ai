import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_stats_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_chip.dart';
import '../widgets/user_avatar.dart';
import 'profile_photo_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _linking = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final authUser = ref.watch(authProvider);
    final firestoreProfile = ref.watch(userProfileProvider).when(
      data: (UserProfile? value) => value,
      loading: () => null,
      error: (Object _, StackTrace _) => null,
    );
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final isGuest = authUser?.isAnonymous ?? true;
    final displayName = firestoreProfile?.effectiveDisplayName ??
        (isGuest
            ? 'Guest Athlete'
            : (authUser?.displayName ?? 'Athlete'));
    final joinDate = firestoreProfile?.createdAt.toDate() ??
        authUser?.metadata.creationTime ??
        DateTime.now();
    final join = _formatJoin(joinDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Column(
            children: [
              // Tap the picture to view it full screen or change it.
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfilePhotoScreen(),
                  ),
                ),
                child: Stack(
                  children: [
                    Hero(
                      tag: kProfileAvatarHeroTag,
                      child: UserAvatar(
                        radius: 44,
                        fontSize: 28,
                        photoUrl: firestoreProfile?.photoUrl,
                        photoBase64: firestoreProfile?.customPhotoBase64,
                        avatarColorHex: firestoreProfile?.avatarColor,
                        initials: firestoreProfile?.initials ??
                            (isGuest
                                ? 'G'
                                : (displayName.trim().isEmpty
                                ? '?'
                                : displayName.trim()[0].toUpperCase())),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
                value: '${firestoreProfile?.workoutsCount ?? stats.totalWorkouts}',
                icon: Icons.fitness_center_rounded,
              ),
              const SizedBox(width: 10),
              StatChip(
                label: 'Total reps',
                value: '${firestoreProfile?.totalReps ?? stats.totalReps}',
                icon: Icons.repeat_rounded,
              ),
              const SizedBox(width: 10),
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
              // ── Guest-only: Link Google Account ──────────────────────────
              if (isGuest) ...[
                _SettingsTile(
                  icon: Icons.link_rounded,
                  title: 'Link Google Account',
                  subtitle: 'Save your progress permanently',
                  loading: _linking,
                  onTap: _linking ? () {} : () => _handleLink(context, ref),
                ),
                Divider(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.5),
                ),
              ],
              // ─────────────────────────────────────────────────────────────
              _SettingsTile(
                icon: Icons.badge_outlined,
                title: 'Edit Display Name',
                subtitle: displayName,
                onTap: _editDisplayName,
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.5)),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Avatar Color',
                subtitle: 'Used when you have no profile photo',
                onTap: _editAvatarColor,
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.5)),
              _SettingsTile(
                icon: Icons.brightness_6_outlined,
                title: 'Appearance',
                subtitle: _themeLabel(themeMode),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _ThemeModeDialog(),
                ),
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.5)),
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

  Future<void> _editDisplayName() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;

    final initial = ref.read(userProfileProvider).maybeWhen(
      data: (profile) => profile?.effectiveDisplayName ?? '',
      orElse: () => '',
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _EditDisplayNameDialog(
        uid: uid,
        initialName: initial,
      ),
    );
  }

  Future<void> _editAvatarColor() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;

    final currentHex = ref.read(userProfileProvider).maybeWhen(
      data: (profile) => profile?.avatarColor,
      orElse: () => null,
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _AvatarColorDialog(
        uid: uid,
        currentHex: currentHex,
      ),
    );
  }

  Future<void> _handleLink(BuildContext context, WidgetRef ref) async {
    // Capture messenger before the async gap to satisfy
    // use_build_context_synchronously.
    final sm = ScaffoldMessenger.of(context);
    setState(() => _linking = true);
    try {
      final result =
      await ref.read(authProvider.notifier).linkGoogleAccount();
      if (!mounted) return;
      switch (result) {
        case LinkSuccess():
          sm.showSnackBar(
            const SnackBar(
              content: Text(
                '🎉 Google account linked! Your progress is now saved permanently.',
              ),
            ),
          );
        case LinkAlreadyInUse():
          sm.showSnackBar(
            const SnackBar(
              content: Text(
                'This Google account is already linked to another profile. '
                    'Sign in with Google instead to access that account '
                    '(your current guest data will not be merged).',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        case LinkCancelled():
        // User dismissed — nothing to show.
          break;
      }
    } catch (_) {
      if (!mounted) return;
      sm.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About FormFit AI'),
        content: const Text(
          'AI pose-tracked fitness competitions. Count your push-ups, check your form and climb the leaderboard.',
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

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({
    required this.uid,
    required this.initialName,
  });

  final String uid;
  final String initialName;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final trimmed = _controller.text.trim();
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'customDisplayName': trimmed.isEmpty ? FieldValue.delete() : trimmed,
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save display name')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Display Name'),
      content: TextField(
        controller: _controller,
        enabled: !_saving,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Leave empty to use your Google name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _AvatarColorDialog extends StatefulWidget {
  const _AvatarColorDialog({
    required this.uid,
    required this.currentHex,
  });

  final String uid;
  final String? currentHex;

  @override
  State<_AvatarColorDialog> createState() => _AvatarColorDialogState();
}

class _AvatarColorDialogState extends State<_AvatarColorDialog> {
  bool _saving = false;

  Future<void> _select(String hex) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'avatarColor': hex,
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save avatar color')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Avatar Color'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final color in AppColors.avatarSwatches)
            _ColorSwatch(
              color: color,
              selected: AppColors.toHex(color) ==
                  widget.currentHex?.toUpperCase(),
              onTap: _saving ? () {} : () => _select(AppColors.toHex(color)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
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
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  /// When `true`, replaces the trailing chevron with a small loading spinner.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: loading
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      )
          : Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
      ),
      onTap: onTap,
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ]
              : null,
        ),
      ),
    );
  }
}

String _themeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System default';
  }
}

class _ThemeModeDialog extends ConsumerWidget {
  const _ThemeModeDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    void choose(ThemeMode mode) {
      ref.read(themeModeProvider.notifier).setMode(mode);
      Navigator.pop(context);
    }

    return AlertDialog(
      title: const Text('Appearance'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            icon: Icons.brightness_auto_rounded,
            title: 'System default',
            subtitle: 'Match your phone’s dark / light mode',
            selected: current == ThemeMode.system,
            onTap: () => choose(ThemeMode.system),
          ),
          _ThemeOption(
            icon: Icons.light_mode_rounded,
            title: 'Light',
            subtitle: 'Always use light mode',
            selected: current == ThemeMode.light,
            onTap: () => choose(ThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.dark_mode_rounded,
            title: 'Dark',
            subtitle: 'Always use dark mode',
            selected: current == ThemeMode.dark,
            onTap: () => choose(ThemeMode.dark),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.accent : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
          : null,
      onTap: onTap,
    );
  }
}