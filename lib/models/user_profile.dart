import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.createdAt,
    required this.lastLoginAt,
    this.photoUrl,
    this.customDisplayName,
    this.avatarColor,
    this.customPhotoBase64,
    this.totalReps = 0,
    this.workoutsCount = 0,
    this.weeklyReps = 0,
    this.weekStartDate,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isGuest;
  final Timestamp createdAt;
  final Timestamp lastLoginAt;

  /// In-app name; when null/empty, [displayName] (Google/guest) is used.
  final String? customDisplayName;

  /// Initials-circle fill as `#RRGGBB`. Null means the app accent color.
  final String? avatarColor;

  /// Small JPEG chosen from the gallery, base64 encoded. When set it is shown
  /// instead of [photoUrl] (the Google photo).
  final String? customPhotoBase64;

  /// Cumulative rep count across all sessions (all-time leaderboard metric).
  final int totalReps;

  /// Total number of completed workout sessions.
  final int workoutsCount;

  /// Rep count accumulated since [weekStartDate] (weekly leaderboard metric).
  /// Resets each week when the user next saves a session.
  final int weeklyReps;

  /// The Monday 00:00 UTC that marks the start of the week [weeklyReps] is
  /// counting. `null` for accounts created before this field was introduced.
  final Timestamp? weekStartDate;

  /// Name shown in the UI: custom override, else Google/guest [displayName].
  String get effectiveDisplayName {
    final custom = customDisplayName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final fallback = displayName.trim();
    if (fallback.isNotEmpty) return fallback;
    return isGuest ? 'Guest Athlete' : 'Athlete';
  }

  String get initials {
    final trimmed = effectiveDisplayName.trim();
    if (trimmed.isEmpty) return isGuest ? 'G' : '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'isGuest': isGuest,
      'customDisplayName': customDisplayName,
      'avatarColor': avatarColor,
      'customPhotoBase64': customPhotoBase64,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'totalReps': totalReps,
      'workoutsCount': workoutsCount,
      'weeklyReps': weeklyReps,
      'weekStartDate': weekStartDate,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      isGuest: map['isGuest'] as bool? ?? false,
      customDisplayName: map['customDisplayName'] as String?,
      avatarColor: map['avatarColor'] as String?,
      customPhotoBase64: map['customPhotoBase64'] as String?,
      createdAt: _timestamp(map['createdAt']),
      lastLoginAt: _timestamp(map['lastLoginAt']),
      totalReps: (map['totalReps'] as num?)?.toInt() ?? 0,
      workoutsCount: (map['workoutsCount'] as num?)?.toInt() ?? 0,
      weeklyReps: (map['weeklyReps'] as num?)?.toInt() ?? 0,
      weekStartDate: map['weekStartDate'] as Timestamp?,
    );
  }

  factory UserProfile.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User profile ${doc.id} has no data.');
    }
    return UserProfile.fromMap({
      ...data,
      'uid': data['uid'] ?? doc.id,
    });
  }

  static Timestamp _timestamp(Object? value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    return Timestamp.now();
  }
}