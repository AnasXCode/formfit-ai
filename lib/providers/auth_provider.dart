import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';

/// Result returned by [AuthNotifier.linkGoogleAccount].
sealed class LinkResult {
  const LinkResult();
}

/// The anonymous account was successfully upgraded to a Google-backed account.
/// The [uid] is unchanged; stats and sessions are preserved.
final class LinkSuccess extends LinkResult {
  const LinkSuccess();
}

/// The Google account being linked is already associated with a *different*
/// Firebase user. No data has been changed.
final class LinkAlreadyInUse extends LinkResult {
  const LinkAlreadyInUse();
}

/// The user dismissed the Google sign-in sheet without completing it.
final class LinkCancelled extends LinkResult {
  const LinkCancelled();
}

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(_initialUser()) {
    if (Firebase.apps.isEmpty) return;
    _subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint(
        'authStateChanges: uid=${user?.uid} isAnonymous=${user?.isAnonymous}',
      );
      state = user;
    });
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
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
    debugPrint(
      'signInAsGuest: before uid=${_auth.currentUser?.uid} '
      'isAnonymous=${_auth.currentUser?.isAnonymous}',
    );

    // signInAnonymously() returns the *existing* user when one is still
    // signed in (anonymous or linked). Always start from a signed-out
    // session so this call creates a brand-new anonymous uid.
    if (_auth.currentUser != null) {
      await signOut();
    }

    final result = await _auth.signInAnonymously();
    final user = result.user;
    debugPrint(
      'signInAsGuest: after uid=${user?.uid} isAnonymous=${user?.isAnonymous}',
    );
    if (user != null) {
      await _syncUserProfile(user);
    }
  }

  /// Creates `users/{uid}` on first login, or updates `lastLoginAt`.
  /// Failures are logged and never block a successful auth session.
  ///
  /// When [isLinking] is `true` (anonymous → Google upgrade), only identity
  /// fields are updated via `update()` so aggregate stats, `createdAt`, and
  /// session data that already exist under this uid are not overwritten.
  Future<void> _syncUserProfile(User user, {bool isLinking = false}) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final now = Timestamp.now();

      if (isLinking) {
        // Patch only identity fields; leave totalReps / workoutsCount /
        // weeklyReps / weekStartDate / createdAt untouched.
        await docRef.update({
          'displayName': user.displayName?.trim().isNotEmpty == true
              ? user.displayName!
              : 'Athlete',
          'email': user.email ?? '',
          'photoUrl': user.photoURL,
          'isGuest': false,
          'lastLoginAt': now,
        });
        return;
      }

      final snapshot = await docRef.get();

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

  /// Links the current **anonymous** Firebase user to a Google credential,
  /// preserving the existing uid, sessions, and stats.
  ///
  /// Returns a [LinkResult] describing the outcome:
  /// - [LinkSuccess] — upgrade succeeded; uid and all data are unchanged.
  /// - [LinkAlreadyInUse] — the Google account is already tied to a different
  ///   Firebase user; the caller should surface a message asking the user to
  ///   sign in with Google instead.
  /// - [LinkCancelled] — the user dismissed the Google sign-in sheet.
  Future<LinkResult> linkGoogleAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || !currentUser.isAnonymous) {
      // Guard: only anonymous users can upgrade.
      return const LinkCancelled();
    }

    try {
      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return const LinkCancelled();
        }
        rethrow;
      }

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google Sign-In did not return an ID token.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      // linkWithCredential keeps the same uid — existing sessions and stats
      // are preserved under users/{uid}.
      final result = await currentUser.linkWithCredential(credential);

      // Patch only identity fields; never overwrite aggregate stats.
      if (result.user != null) {
        await _syncUserProfile(result.user!, isLinking: true);
        state = result.user;
      }

      return const LinkSuccess();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // The Google account belongs to a separate Firebase user. We do NOT
        // attempt any data merge — that is explicitly out of scope.
        debugPrint('linkGoogleAccount: credential already in use — ${e.message}');
        return const LinkAlreadyInUse();
      }
      debugPrint('linkGoogleAccount FirebaseAuthException [${e.code}]: ${e.message}');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('linkGoogleAccount failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Future<void> signOut() async {
    debugPrint(
      'signOut: before uid=${_auth.currentUser?.uid} '
      'isAnonymous=${_auth.currentUser?.isAnonymous}',
    );

    // Drop the Google session first so a persisted Google token cannot
    // silently restore a linked Firebase user after we sign out of Auth.
    try {
      await _ensureGoogleInitialized();
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // Guest sessions never authenticate with Google.
    }

    await _auth.signOut();
    // Don't wait for authStateChanges — stale non-null state would make
    // the router treat the user as still logged in and bounce /auth → /home.
    state = null;

    debugPrint('signOut: after uid=${_auth.currentUser?.uid}');
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
