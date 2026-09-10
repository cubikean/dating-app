import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/chat/chat_detail_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/discovery/discovery_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/matches/matches_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

/// Petit helper qui transforme un Stream/AsyncValue Riverpod en
/// `Listenable`, pour que go_router puisse re-évaluer `redirect` chaque
/// fois que l'état d'auth ou de profil change.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProfileProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuthLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull != null;

      final goingToSplash = state.matchedLocation == '/splash';
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (isAuthLoading) {
        return goingToSplash ? null : '/splash';
      }

      if (!isLoggedIn) {
        return goingToAuth ? null : '/login';
      }

      // Connecté : vérifier si l'onboarding (création de profil) est fait.
      final profileState = ref.read(currentUserProfileProvider);
      final profile = profileState.valueOrNull;
      final onboardingDone = profile?.onboardingComplete ?? false;
      final goingToOnboarding = state.matchedLocation == '/onboarding';

      if (!onboardingDone && !profileState.isLoading) {
        return goingToOnboarding ? null : '/onboarding';
      }

      if ((goingToAuth || goingToSplash || goingToOnboarding) &&
          onboardingDone) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Coquille avec bottom navigation : discovery / matches / chats / profil.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/',
                builder: (context, state) => const DiscoveryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chats',
              builder: (context, state) => const ChatListScreen(),
              routes: [
                GoRoute(
                  path: ':matchId',
                  builder: (context, state) => ChatDetailScreen(
                    matchId: state.pathParameters['matchId']!,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
