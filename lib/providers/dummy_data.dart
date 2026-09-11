import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../models/leaderboard_entry.dart';
import '../models/user_profile.dart';
import '../models/workout_session.dart';

final currentUserProvider = Provider<UserProfile>((ref) {
  return UserProfile(
    id: 'me',
    name: 'Alex Rivera',
    rank: 4,
    joinDate: DateTime(2026, 3, 12),
    totalWorkouts: 28,
    totalReps: 1840,
    bestStreak: 12,
    currentStreak: 6,
    todayReps: 42,
    weeklyTotal: 318,
  );
});

final exercisesProvider = Provider<List<Exercise>>((ref) {
  return const [
    Exercise(
      id: 'pushups',
      name: 'Push-Ups',
      icon: Icons.fitness_center_rounded,
      available: true,
      subtitle: 'AI form tracking ready',
    ),
    Exercise(
      id: 'squats',
      name: 'Squats',
      icon: Icons.accessibility_new_rounded,
      available: false,
      subtitle: 'Coming soon',
    ),
    Exercise(
      id: 'situps',
      name: 'Sit-ups',
      icon: Icons.self_improvement_rounded,
      available: false,
      subtitle: 'Coming soon',
    ),
    Exercise(
      id: 'lunges',
      name: 'Lunges',
      icon: Icons.directions_run_rounded,
      available: false,
      subtitle: 'Coming soon',
    ),
  ];
});

final historyProvider = Provider<List<WorkoutSession>>((ref) {
  final now = DateTime.now();
  return [
    WorkoutSession(
      id: 's1',
      exerciseId: 'pushups',
      exerciseName: 'Push-Ups',
      reps: 42,
      duration: const Duration(minutes: 4, seconds: 18),
      formAccuracy: 91,
      completedAt: now.subtract(const Duration(hours: 3)),
    ),
    WorkoutSession(
      id: 's2',
      exerciseId: 'pushups',
      exerciseName: 'Push-Ups',
      reps: 35,
      duration: const Duration(minutes: 3, seconds: 52),
      formAccuracy: 88,
      completedAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
    WorkoutSession(
      id: 's3',
      exerciseId: 'pushups',
      exerciseName: 'Push-Ups',
      reps: 50,
      duration: const Duration(minutes: 5, seconds: 7),
      formAccuracy: 94,
      completedAt: now.subtract(const Duration(days: 2, hours: 5)),
    ),
    WorkoutSession(
      id: 's4',
      exerciseId: 'pushups',
      exerciseName: 'Push-Ups',
      reps: 28,
      duration: const Duration(minutes: 3, seconds: 11),
      formAccuracy: 82,
      completedAt: now.subtract(const Duration(days: 3, hours: 1)),
    ),
    WorkoutSession(
      id: 's5',
      exerciseId: 'pushups',
      exerciseName: 'Push-Ups',
      reps: 61,
      duration: const Duration(minutes: 6, seconds: 44),
      formAccuracy: 90,
      completedAt: now.subtract(const Duration(days: 5)),
    ),
  ];
});

final weeklyLeaderboardProvider = Provider<List<LeaderboardEntry>>((ref) {
  return const [
    LeaderboardEntry(
      rank: 1,
      userId: 'u1',
      name: 'Jordan Lee',
      reps: 512,
    ),
    LeaderboardEntry(
      rank: 2,
      userId: 'u2',
      name: 'Sam Okonkwo',
      reps: 478,
    ),
    LeaderboardEntry(
      rank: 3,
      userId: 'u3',
      name: 'Priya Shah',
      reps: 441,
    ),
    LeaderboardEntry(
      rank: 4,
      userId: 'me',
      name: 'Alex Rivera',
      reps: 318,
      isCurrentUser: true,
    ),
    LeaderboardEntry(
      rank: 5,
      userId: 'u5',
      name: 'Chris Nguyen',
      reps: 290,
    ),
    LeaderboardEntry(
      rank: 6,
      userId: 'u6',
      name: 'Maya Chen',
      reps: 264,
    ),
    LeaderboardEntry(
      rank: 7,
      userId: 'u7',
      name: 'Luis Ortega',
      reps: 221,
    ),
    LeaderboardEntry(
      rank: 8,
      userId: 'u8',
      name: 'Nora Patel',
      reps: 198,
    ),
  ];
});

final allTimeLeaderboardProvider = Provider<List<LeaderboardEntry>>((ref) {
  return const [
    LeaderboardEntry(
      rank: 1,
      userId: 'u2',
      name: 'Sam Okonkwo',
      reps: 4120,
    ),
    LeaderboardEntry(
      rank: 2,
      userId: 'u1',
      name: 'Jordan Lee',
      reps: 3894,
    ),
    LeaderboardEntry(
      rank: 3,
      userId: 'u3',
      name: 'Priya Shah',
      reps: 3601,
    ),
    LeaderboardEntry(
      rank: 4,
      userId: 'u5',
      name: 'Chris Nguyen',
      reps: 2210,
    ),
    LeaderboardEntry(
      rank: 5,
      userId: 'me',
      name: 'Alex Rivera',
      reps: 1840,
      isCurrentUser: true,
    ),
    LeaderboardEntry(
      rank: 6,
      userId: 'u6',
      name: 'Maya Chen',
      reps: 1702,
    ),
    LeaderboardEntry(
      rank: 7,
      userId: 'u7',
      name: 'Luis Ortega',
      reps: 1544,
    ),
    LeaderboardEntry(
      rank: 8,
      userId: 'u8',
      name: 'Nora Patel',
      reps: 1290,
    ),
  ];
});
