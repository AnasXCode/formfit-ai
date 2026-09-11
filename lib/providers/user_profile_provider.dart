import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'auth_provider.dart';

/// Live `users/{uid}` document for the signed-in user, or `null` if missing.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream<UserProfile?>.value(null);
  }

  final user = ref.watch(authProvider);
  if (user == null) {
    return Stream<UserProfile?>.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return UserProfile.fromFirestore(doc);
      });
});
