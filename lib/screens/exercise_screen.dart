import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  /// Seconds of "get ready" before counting starts.
  static const int _countdownSeconds = 3;

  Timer? _countdownTimer;
  Timer? _clock;
  final PushUpCounter _counter = PushUpCounter();

  int _countdown = _countdownSeconds;

  /// `false` during the 3-2-1 countdown: no counting and the timer is not
  /// running yet.
  bool _started = false;

  /// `true` while paused: the clock and rep counting stop, the countdown
  /// stays finished, and the last camera frame is still shown.
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    // The camera preview / skeleton mapping assumes portrait.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // Keep the screen on for the whole workout (the camera would stop otherwise).
    WakelockPlus.enable();

    Future.microtask(() {
      if (mounted) ref.read(activeWorkoutProvider.notifier).reset();
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _beginWorkout();
      }
    });
  }

  void _beginWorkout() {
    _counter.reset();
    ref.read(activeWorkoutProvider.notifier).reset();
    setState(() => _started = true);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      ref.read(activeWorkoutProvider.notifier).tick();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _clock?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// Called by the camera view for every processed frame.
  void _onPose(Pose? pose) {
    if (!mounted || !_started || _paused) return;
    final update = _counter.update(pose);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    if (update.repCounted) notifier.addRep();
    notifier.setForm(ok: update.formOk, message: update.message);
  }

  void _togglePause() {
    if (!_started) return;
    setState(() => _paused = !_paused);
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
                      const SizedBox(width: 8),
                      if (_started)
                        _PauseButton(paused: _paused, onTap: _togglePause),
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
                      color: Colors.white.withValues(alpha: _paused ? 0.4 : 1),
                      fontSize: 92,
                      shadows: const [
                        Shadow(blurRadius: 18, color: Colors.black54),
                      ],
                    ),
                  ),
                  Text(
                    _paused ? 'PAUSED' : 'REPS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _paused ? AppColors.warning : Colors.white70,
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
          if (!_started)
            Positioned.fill(
              // Let taps through so "End session" still works.
              child: IgnorePointer(child: _CountdownOverlay(value: _countdown)),
            ),
          if (_started && _paused)
            Positioned.fill(
              child: _PausedOverlay(onResume: _togglePause),
            ),
        ],
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.paused, required this.onTap});

  final bool paused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(
          paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_outline_rounded,
                size: 72, color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              'Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Get into position',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 1.6, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                '$value',
                key: ValueKey<int>(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 150,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
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