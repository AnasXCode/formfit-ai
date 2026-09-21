import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session.dart';
import 'leaderboard_provider.dart';
import 'sessions_provider.dart';
import 'user_profile_provider.dart';

/// Real numbers for the Home dashboard, calculated from the user's saved
/// sessions. Days and weeks use the phone's local time (weeks start Monday),
/// the same as the History screen.
class DashboardStats {
  const DashboardStats({
    this.todayReps = 0,
    this.weekReps = 0,
    this.currentStreak = 0,
  });

  /// Reps done today.
  final int todayReps;

  /// Reps done since Monday 00:00 (local time).
  final int weekReps;

  /// Consecutive days with at least one workout. Stays alive if you worked out
  /// yesterday but not yet today, and drops to 0 after a missed day.
  final int currentStreak;

  factory DashboardStats.fromSessions(
      List<WorkoutSession> sessions,
      DateTime now,
      ) {
    DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

    final today = dayOf(now);
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );

    var todayReps = 0;
    var weekReps = 0;
    final activeDays = <DateTime>{};

    for (final s in sessions) {
      if (s.reps <= 0) continue;
      final day = dayOf(s.completedAt);
      activeDays.add(day);
      if (day == today) todayReps += s.reps;
      if (!day.isBefore(weekStart)) weekReps += s.reps;
    }

    // Count back from today (or from yesterday if nothing was done today yet).
    var cursor = activeDays.contains(today)
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    return DashboardStats(
      todayReps: todayReps,
      weekReps: weekReps,
      currentStreak: streak,
    );
  }
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final sessions =
      ref.watch(sessionsProvider).valueOrNull ?? const <WorkoutSession>[];
  return DashboardStats.fromSessions(sessions, DateTime.now());
});

/// The signed-in user's real ALL-TIME leaderboard rank, or `null` when they
/// have none: guests are not on the leaderboard, and neither are users who
/// have not saved a workout yet.
///
/// Inside the top 50 it uses the same position as the Leaderboard screen.
/// Below the top 50 it counts how many players have more total reps.
final myRankProvider = FutureProvider<int?>((ref) async {
  if (Firebase.apps.isEmpty) return null;

  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null || profile.isGuest || profile.totalReps <= 0) {
    return null;
  }

  final board = ref.watch(allTimeLeaderboardProvider).valueOrNull;
  if (board != null) {
    for (final entry in board) {
      if (entry.isCurrentUser) return entry.rank;
    }
  }

  try {
    final ahead = await FirebaseFirestore.instance
        .collection('users')
        .where('isGuest', isEqualTo: false)
        .where('totalReps', isGreaterThan: profile.totalReps)
        .count()
        .get();
    return (ahead.count ?? 0) + 1;
  } catch (_) {
    return null;
  }
});