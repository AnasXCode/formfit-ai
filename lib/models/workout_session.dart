class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.reps,
    required this.duration,
    required this.formAccuracy,
    required this.completedAt,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final int reps;
  final Duration duration;
  final double formAccuracy;
  final DateTime completedAt;

  String get durationLabel {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final h = duration.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }
}
