import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/sessions_provider.dart';
import '../providers/workout_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

class ExerciseSummaryScreen extends ConsumerStatefulWidget {
  const ExerciseSummaryScreen({super.key});

  @override
  ConsumerState<ExerciseSummaryScreen> createState() =>
      _ExerciseSummaryScreenState();
}

class _ExerciseSummaryScreenState extends ConsumerState<ExerciseSummaryScreen> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _saveAndContinue() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });

    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(lastSessionProvider);
    final user = ref.read(authProvider);

    var result = SaveResult.saved;
    // A session with no reps has nothing worth saving.
    if (session != null && user != null && session.reps > 0) {
      result = await saveWorkoutSession(uid: user.uid, session: session);
    }

    if (!mounted) return;

    if (result == SaveResult.failed) {
      // Stay on this screen, keep the workout in memory and offer a retry.
      setState(() {
        _saving = false;
        _failed = true;
      });
      return;
    }

    if (result == SaveResult.queued) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No connection. Your workout is stored on this phone and will '
                'upload automatically when you are online.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }

    context.go('/home');
  }

  void _discard() {
    ref.read(lastSessionProvider.notifier).state = null;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lastSessionProvider);
    final scheme = Theme.of(context).colorScheme;

    final reps = session?.reps ?? 24;
    final duration = session?.durationLabel ?? '03:12';
    final accuracy = session?.formAccuracy ?? 91;
    final name = session?.exerciseName ?? 'Push-Ups';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session complete',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _MetricCard(label: 'Reps', value: '$reps'),
                  const SizedBox(width: 10),
                  _MetricCard(label: 'Duration', value: duration),
                  const SizedBox(width: 10),
                  _MetricCard(
                    label: 'Form',
                    value: '${accuracy.toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const Spacer(),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_failed) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: scheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Couldn’t save your workout. Check your connection and try again.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              PrimaryButton(
                label: _saving
                    ? 'Saving…'
                    : (_failed ? 'Try again' : 'Save & Continue'),
                onPressed: _saving ? null : _saveAndContinue,
              ),
              if (_failed)
                TextButton(
                  onPressed: _saving ? null : _discard,
                  child: const Text('Discard this workout'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}