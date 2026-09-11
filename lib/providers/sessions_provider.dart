import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session.dart';
import 'auth_provider.dart';

/// Live `users/{uid}/sessions` list, newest first.
final sessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream<List<WorkoutSession>>.value(const []);
  }

  final user = ref.watch(authProvider);
  if (user == null) {
    return Stream<List<WorkoutSession>>.value(const []);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('sessions')
      .orderBy('completedAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(WorkoutSession.fromFirestore)
            .toList(growable: false),
      );
});

/// Writes `users/{uid}/sessions/{autoId}`. Failures are logged and not rethrown.
Future<void> saveWorkoutSession({
  required String uid,
  required WorkoutSession session,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .add(session.toMap());
  } catch (error, stackTrace) {
    debugPrint('Failed to save workout session: $error');
    debugPrint('$stackTrace');
  }
}
