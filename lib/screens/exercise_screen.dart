import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/workout_session.dart';
import '../pose/push_up_counter.dart';
import '../providers/workout_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_camera_view.dart';

/// Live camera preview with real pose detection, form feedback and rep counting.
class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  Timer? _clock;
  final PushUpCounter _counter = PushUpCounter();

  @override
  void initState() {
    super.initState();
    // The camera preview / skeleton mapping assumes portrait.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    Future.microtask(() {
      if (mounted) ref.read(activeWorkoutProvider.notifier).reset();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      ref.read(activeWorkoutProvider.notifier).tick();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// Called by the camera view for every processed frame.
  void _onPose(Pose? pose) {
    if (!mounted) return;
    final update = _counter.update(pose);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    if (update.repCounted) notifier.addRep();
    notifier.setForm(ok: update.formOk, message: update.message);
  }

  void _endSession() {
    final live = ref.read(activeWorkoutProvider);
    ref.read(lastSessionProvider.notifier).state = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exerciseId: widget.exerciseId,
      exerciseName: 'Push-Ups',
      reps: live.reps,
      duration: live.elapsed,
      formAccuracy: _counter.accuracy,
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
          Positioned.fill(
            child: ExerciseCameraView(
              onPose: _onPose,
              skeletonColor:
              live.formOk ? AppColors.success : AppColors.warning,
            ),
          ),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _FormBadge(
                            ok: live.formOk,
                            label: live.formStatus,
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 8),
                  // DEBUG: live angles. Remove once tuning is done.
                  ValueListenableBuilder<String>(
                    valueListenable: _counter.debug,
                    builder: (context, value, child) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
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
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}