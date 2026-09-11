import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.onboardingComplete = false,
    this.status = AuthStatus.unauthenticated,
    this.isGuest = false,
  });

  final bool onboardingComplete;
  final AuthStatus status;
  final bool isGuest;

  bool get isLoggedIn => status == AuthStatus.authenticated;

  AuthState copyWith({
    bool? onboardingComplete,
    AuthStatus? status,
    bool? isGuest,
  }) {
    return AuthState(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      status: status ?? this.status,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void completeOnboarding() {
    state = state.copyWith(onboardingComplete: true);
  }

  void continueWithGoogle() {
    state = state.copyWith(
      onboardingComplete: true,
      status: AuthStatus.authenticated,
      isGuest: false,
    );
  }

  void continueAsGuest() {
    state = state.copyWith(
      onboardingComplete: true,
      status: AuthStatus.authenticated,
      isGuest: true,
    );
  }

  void logout() {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isGuest: false,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
