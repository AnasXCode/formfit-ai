import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(_initialUser()) {
    if (Firebase.apps.isEmpty) return;
    _subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      state = user;
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<User?>? _subscription;
  bool _googleInitialized = false;

  static User? _initialUser() {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser;
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  Future<void> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In did not return an ID token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      await _syncUserProfile(user);
    }
  }

  Future<void> signInAsGuest() async {
    final result = await _auth.signInAnonymously();
    final user = result.user;
    if (user != null) {
      await _syncUserProfile(user);
    }
  }

  /// Creates `users/{uid}` on first login, or updates `lastLoginAt`.
  /// Failures are logged and never block a successful auth session.
  Future<void> _syncUserProfile(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final snapshot = await docRef.get();
      final now = Timestamp.now();

      if (snapshot.exists) {
        await docRef.update({'lastLoginAt': now});
        return;
      }

      final isGuest = user.isAnonymous;
      final profile = UserProfile(
        uid: user.uid,
        displayName: isGuest
            ? 'Guest Athlete'
            : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!
                : 'Athlete'),
        email: user.email ?? '',
        photoUrl: user.photoURL,
        isGuest: isGuest,
        createdAt: now,
        lastLoginAt: now,
      );
      await docRef.set(profile.toMap());
    } catch (error, stackTrace) {
      debugPrint('Failed to sync Firestore user profile: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Guest sessions never authenticate with Google.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier();
});

/// In-memory onboarding flag (not persisted yet).
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false);

  void complete() => state = true;
}

final onboardingCompleteProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});
