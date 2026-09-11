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

  Future<void> _saveAndContinue() async {
    if (_saving) return;
    setState(() => _saving = true);

    final session = ref.read(lastSessionProvider);
    final user = ref.read(authProvider);
    if (session != null && user != null) {
      await saveWorkoutSession(uid: user.uid, session: session);
    }

    if (!mounted) return;
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
              PrimaryButton(
                label: _saving ? 'Saving…' : 'Save & Continue',
                onPressed: _saving ? null : _saveAndContinue,
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
