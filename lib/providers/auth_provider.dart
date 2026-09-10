import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream de l'utilisateur Firebase courant (null = déconnecté).
/// Le router (`app_router.dart`) écoute ce provider pour rediriger
/// automatiquement entre les écrans publics et privés.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Contrôleur exposant les actions d'authentification (login/register/logout)
/// avec un état de chargement/erreur simple, consommé par les écrans d'auth.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AsyncData(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authService.signInWithEmail(email, password),
    );
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authService.registerWithEmail(email, password),
    );
  }

  Future<void> signOut() => _authService.signOut();
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
