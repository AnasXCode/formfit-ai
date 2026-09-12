import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/workout_session.dart';
import '../providers/workout_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_camera_view.dart';

/// Live camera preview with dummy timer/rep overlay (pose detection comes later).
class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  Timer? _clock;
  Timer? _demo;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(activeWorkoutProvider.notifier).reset();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      ref.read(activeWorkoutProvider.notifier).tick();
    });
    // Dummy activity so the overlay feels alive before real pose logic.
    _demo = Timer.periodic(const Duration(seconds: 2), (t) {
      final n = ref.read(activeWorkoutProvider.notifier);
      n.addRep();
      n.setForm(ok: t.tick % 4 != 0);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _demo?.cancel();
    super.dispose();
  }

  void _endSession() {
    final live = ref.read(activeWorkoutProvider);
    final accuracy = live.reps == 0 ? 0.0 : 87.0 + (live.reps % 8);
    ref.read(lastSessionProvider.notifier).state = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exerciseId: widget.exerciseId,
      exerciseName: 'Push-Ups',
      reps: live.reps,
      duration: live.elapsed,
      formAccuracy: accuracy.clamp(70, 99).toDouble(),
      completedAt: DateTime.now(),
    );
    context.go('/summary');
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(activeWorkoutProvider);
    final m = live.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = live.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: ExerciseCameraView()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _HudChip(
                        icon: Icons.timer_outlined,
                        label: '$m:$s',
                      ),
                      const Spacer(),
                      _FormBadge(ok: live.formOk, label: live.formStatus),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${live.reps}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 92,
                          shadows: const [
                            Shadow(blurRadius: 18, color: Colors.black54),
                          ],
                        ),
                  ),
                  Text(
                    'REPS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 4,
                        ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _endSession,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: const Text('End session'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormBadge extends StatelessWidget {
  const _FormBadge({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
