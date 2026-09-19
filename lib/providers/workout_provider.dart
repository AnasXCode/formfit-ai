import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session.dart';

class ActiveWorkout {
  const ActiveWorkout({
    this.reps = 0,
    this.elapsed = Duration.zero,
    this.formStatus = 'Get into push-up position',
    this.formOk = true,
  });

  final int reps;
  final Duration elapsed;
  final String formStatus;
  final bool formOk;

  ActiveWorkout copyWith({
    int? reps,
    Duration? elapsed,
    String? formStatus,
    bool? formOk,
  }) {
    return ActiveWorkout(
      reps: reps ?? this.reps,
      elapsed: elapsed ?? this.elapsed,
      formStatus: formStatus ?? this.formStatus,
      formOk: formOk ?? this.formOk,
    );
  }
}

class ActiveWorkoutNotifier extends Notifier<ActiveWorkout> {
  @override
  ActiveWorkout build() => const ActiveWorkout();

  void tick() {
    state = state.copyWith(
      elapsed: state.elapsed + const Duration(seconds: 1),
    );
  }

  void addRep() {
    state = state.copyWith(reps: state.reps + 1);
  }

  /// Called for every camera frame, so it only updates state when something
  /// actually changed (avoids rebuilding the screen 15 times per second).
  void setForm({required bool ok, String? message}) {
    final status = message ?? (ok ? 'Good form' : 'Check your form');
    if (state.formOk == ok && state.formStatus == status) return;
    state = state.copyWith(formOk: ok, formStatus: status);
  }

  void reset() {
    state = const ActiveWorkout();
  }
}

final activeWorkoutProvider =
NotifierProvider<ActiveWorkoutNotifier, ActiveWorkout>(
  ActiveWorkoutNotifier.new,
);

final lastSessionProvider = StateProvider<WorkoutSession?>((ref) => null);