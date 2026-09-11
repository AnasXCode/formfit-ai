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
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isGuest;
  final Timestamp createdAt;
  final Timestamp lastLoginAt;

  String get initials {
    final trimmed = displayName.trim();
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
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      isGuest: map['isGuest'] as bool? ?? false,
      createdAt: _timestamp(map['createdAt']),
      lastLoginAt: _timestamp(map['lastLoginAt']),
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
