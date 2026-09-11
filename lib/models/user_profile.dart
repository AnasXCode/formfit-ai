class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.rank,
    required this.joinDate,
    required this.totalWorkouts,
    required this.totalReps,
    required this.bestStreak,
    required this.currentStreak,
    required this.todayReps,
    required this.weeklyTotal,
    this.isGuest = false,
  });

  final String id;
  final String name;
  final int rank;
  final DateTime joinDate;
  final int totalWorkouts;
  final int totalReps;
  final int bestStreak;
  final int currentStreak;
  final int todayReps;
  final int weeklyTotal;
  final bool isGuest;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  UserProfile copyWith({String? name, bool? isGuest}) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      rank: rank,
      joinDate: joinDate,
      totalWorkouts: totalWorkouts,
      totalReps: totalReps,
      bestStreak: bestStreak,
      currentStreak: currentStreak,
      todayReps: todayReps,
      weeklyTotal: weeklyTotal,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
