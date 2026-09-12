import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/leaderboard_entry.dart';
import 'auth_provider.dart';
import 'sessions_provider.dart';

const int _kLeaderboardLimit = 50;

/// Maps a Firestore [QuerySnapshot] to a ranked [List<LeaderboardEntry>].
///
/// [repField] is the field name to use for the rep count ('totalReps' or
/// 'weeklyReps'). [currentUid] is used to flag the signed-in user's entry.
List<LeaderboardEntry> _mapSnapshot(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  String repField,
  String? currentUid,
) {
  final entries = <LeaderboardEntry>[];
  for (var i = 0; i < snapshot.docs.length; i++) {
    final doc = snapshot.docs[i];
    final data = doc.data();
    final reps = (data[repField] as num?)?.toInt() ?? 0;
    entries.add(
      LeaderboardEntry(
        rank: i + 1,
        userId: doc.id,
        name: _effectiveName(data),
        reps: reps,
        isCurrentUser: doc.id == currentUid,
        avatarColor: data['avatarColor'] as String?,
      ),
    );
  }
  return _disambiguateNames(entries);
}

String _effectiveName(Map<String, dynamic> data) {
  final custom = (data['customDisplayName'] as String?)?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  final google = (data['displayName'] as String?)?.trim();
  if (google != null && google.isNotEmpty) return google;
  return 'Athlete';
}

/// Appends `#` + last 4 uid chars to names that collide in [entries] only.
List<LeaderboardEntry> _disambiguateNames(List<LeaderboardEntry> entries) {
  final counts = <String, int>{};
  for (final entry in entries) {
    final key = entry.name.trim().toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
  }

  return [
    for (final entry in entries)
      if ((counts[entry.name.trim().toLowerCase()] ?? 0) > 1)
        LeaderboardEntry(
          rank: entry.rank,
          userId: entry.userId,
          name: '${entry.name} #${_uidTag(entry.userId)}',
          reps: entry.reps,
          isCurrentUser: entry.isCurrentUser,
          avatarColor: entry.avatarColor,
        )
      else
        entry,
  ];
}

String _uidTag(String uid) {
  if (uid.isEmpty) return '????';
  final start = uid.length >= 4 ? uid.length - 4 : 0;
  return uid.substring(start).toUpperCase();
}

/// Live all-time leaderboard: [users] collection ordered by [totalReps] desc,
/// limited to [_kLeaderboardLimit] entries.
///
/// Emits an empty list while Firebase is not initialised or no user is
/// signed in.
final allTimeLeaderboardProvider =
    StreamProvider<List<LeaderboardEntry>>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream<List<LeaderboardEntry>>.value(const []);
  }

  final currentUser = ref.watch(authProvider);

  return FirebaseFirestore.instance
      .collection('users')
      .where('isGuest', isEqualTo: false)
      .orderBy('totalReps', descending: true)
      .limit(_kLeaderboardLimit)
      .snapshots()
      .map((snap) => _mapSnapshot(snap, 'totalReps', currentUser?.uid));
});

/// Live weekly leaderboard: non-guest users whose [weekStartDate] is this
/// ISO week, ordered by [weeklyReps] desc, limited to [_kLeaderboardLimit].
///
/// Stale last-week scores are excluded by the [weekStartDate] filter rather
/// than a scheduled reset. Users with no [weekStartDate] (never worked out)
/// are also excluded — Firestore inequality filters skip missing fields.
///
/// Inequality on [weekStartDate] requires it as the first [orderBy]; all
/// qualifying docs share the same Monday 00:00 UTC value, so ranking is
/// still by [weeklyReps].
final weeklyLeaderboardProvider =
    StreamProvider<List<LeaderboardEntry>>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream<List<LeaderboardEntry>>.value(const []);
  }

  final currentUser = ref.watch(authProvider);
  final weekStart = Timestamp.fromDate(startOfThisWeek());

  return FirebaseFirestore.instance
      .collection('users')
      .where('isGuest', isEqualTo: false)
      .where('weekStartDate', isGreaterThanOrEqualTo: weekStart)
      .orderBy('weekStartDate')
      .orderBy('weeklyReps', descending: true)
      .limit(_kLeaderboardLimit)
      .snapshots()
      .map((snap) => _mapSnapshot(snap, 'weeklyReps', currentUser?.uid));
});
