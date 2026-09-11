import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session.dart';

class ActiveWorkout {
  const ActiveWorkout({
    this.reps = 0,
    this.elapsed = Duration.zero,
    this.formStatus = 'Good form',
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

  void setForm({required bool ok}) {
    state = state.copyWith(
      formOk: ok,
      formStatus: ok ? 'Good form' : 'Check elbows',
    );
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
