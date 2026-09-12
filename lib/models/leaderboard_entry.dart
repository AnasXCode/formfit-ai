class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.reps,
    this.isCurrentUser = false,
    this.avatarColor,
  });

  final int rank;
  final String userId;
  final String name;
  final int reps;
  final bool isCurrentUser;
  final String? avatarColor;

  String get initials {
    var base = name.trim();
    final tag = RegExp(r' #[0-9A-Fa-f]{1,4}$').firstMatch(base);
    if (tag != null) base = base.substring(0, tag.start).trim();
    final parts = base.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
