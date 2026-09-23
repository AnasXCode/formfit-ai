import 'dart:async';

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

/// Returns the start of the current ISO week (Monday 00:00:00 UTC).
///
/// Shared by session writes (`weekStartDate`) and the weekly leaderboard
/// query so both sides use the same week boundary.
DateTime startOfThisWeek() {
  final now = DateTime.now().toUtc();
  // weekday: Monday = 1, Sunday = 7
  return DateTime.utc(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
}

/// What happened when a workout was saved.
enum SaveResult {
  /// Confirmed by the server.
  saved,

  /// No connection right now. Firestore keeps the write on the phone and sends
  /// it automatically when the internet is back, so the workout is NOT lost.
  /// Do not save it again (that would create a duplicate).
  queued,

  /// The write was rejected (for example by the security rules). Nothing was
  /// saved; it is safe to try again.
  failed,
}

/// Atomically writes `users/{uid}/sessions/{autoId}` and updates the
/// aggregate fields on `users/{uid}` (totalReps, workoutsCount, weeklyReps,
/// weekStartDate) in a single [WriteBatch].
Future<SaveResult> saveWorkoutSession({
  required String uid,
  required WorkoutSession session,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final sessionsRef = userRef.collection('sessions');

    // Read the current user doc to decide whether the weekly counter needs
    // resetting. A single get() before the batch is sufficient; a full
    // transaction is not needed here because weeklyReps is per-user and
    // concurrent writes from the same account within the same second are
    // extremely unlikely.
    final userSnap = await userRef.get();
    final weekStart = startOfThisWeek();

    // Determine whether weeklyReps should be reset.
    Timestamp? storedWeekStart;
    if (userSnap.exists) {
      storedWeekStart = userSnap.data()?['weekStartDate'] as Timestamp?;
    }

    final bool needsWeekReset = storedWeekStart == null ||
        storedWeekStart.toDate().isBefore(weekStart);

    final batch = firestore.batch();

    // 1. Add the new session document.
    batch.set(sessionsRef.doc(), session.toMap());

    // 2. Build the user-doc update map.
    final Map<String, Object> userUpdate = {
      'totalReps': FieldValue.increment(session.reps),
      'workoutsCount': FieldValue.increment(1),
    };

    if (needsWeekReset) {
      // Start a fresh weekly counter from this session.
      userUpdate['weeklyReps'] = session.reps;
      userUpdate['weekStartDate'] = Timestamp.fromDate(weekStart);
    } else {
      // Accumulate into the existing weekly counter.
      userUpdate['weeklyReps'] = FieldValue.increment(session.reps);
    }

    batch.update(userRef, userUpdate);

    try {
      // Offline, commit() never finishes on its own (Firestore waits for the
      // server), so give it a few seconds and then treat it as queued.
      await batch.commit().timeout(const Duration(seconds: 8));
      return SaveResult.saved;
    } on TimeoutException {
      return SaveResult.queued;
    }
  } catch (error, stackTrace) {
    debugPrint('Failed to save workout session: $error');
    debugPrint('$stackTrace');
    return SaveResult.failed;
  }
}