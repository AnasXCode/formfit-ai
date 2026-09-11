import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'reps': reps,
      'durationMs': duration.inMilliseconds,
      'formAccuracy': formAccuracy,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String? ?? '',
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      reps: (map['reps'] as num?)?.toInt() ?? 0,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      formAccuracy: (map['formAccuracy'] as num?)?.toDouble() ?? 0,
      completedAt: _dateTime(map['completedAt']),
    );
  }

  factory WorkoutSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Workout session ${doc.id} has no data.');
    }
    return WorkoutSession.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  static DateTime _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
