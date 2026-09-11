import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/exercise_screen.dart';
import '../screens/exercise_summary_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/app_scaffold_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(authProvider);
      final onboardingComplete = ref.read(onboardingCompleteProvider);
      final loc = state.matchedLocation;

      final onOnboarding = loc == '/onboarding';
      final onAuth = loc == '/auth';
      final loggedIn = user != null;

      if (loggedIn && (onOnboarding || onAuth)) {
        return '/home';
      }
      if (!loggedIn && !onboardingComplete && !onOnboarding) {
        return '/onboarding';
      }
      if (!loggedIn && onboardingComplete && !onAuth) {
        return '/auth';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/exercise/:id',
        builder: (context, state) => ExerciseScreen(
          exerciseId: state.pathParameters['id'] ?? 'pushups',
        ),
      ),
      GoRoute(
        path: '/summary',
        builder: (context, state) => const ExerciseSummaryScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffoldShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HistoryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leaderboard',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: LeaderboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
    ref.listen(onboardingCompleteProvider, (previous, next) => notifyListeners());
  }
}
