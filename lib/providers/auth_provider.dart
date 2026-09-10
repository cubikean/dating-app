import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/account_service.dart';
import 'messaging_provider.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream de l'utilisateur Firebase courant (null = déconnecté).
/// Le router (`app_router.dart`) écoute ce provider pour rediriger
/// automatiquement entre les écrans publics et privés.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Utilisateur courant, rafraîchi aussi après un `reload()`. Le router
/// s'appuie sur `authStateProvider`, plus stable ; ce provider-ci sert aux
/// écrans qui doivent voir la vérification d'adresse aboutir.
final currentUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userChanges();
});

/// Contrôleur exposant les actions d'authentification (login/register/logout)
/// avec un état de chargement/erreur simple, consommé par les écrans d'auth.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final AccountService _accountService;
  final MessagingService _messagingService;

  AuthController(
    this._authService,
    this._accountService,
    this._messagingService,
  ) : super(const AsyncData(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authService.signInWithEmail(email, password),
    );
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _authService.registerWithEmail(email, password);
      // Envoyée dans la foulée : l'adresse doit être confirmée pour limiter
      // les faux profils. L'échec de cet envoi ne doit pas faire échouer
      // l'inscription, l'email est renvoyable depuis l'application.
      try {
        await _authService.sendEmailVerification();
      } catch (_) {}
    });
  }

  Future<void> sendEmailVerification() => _authService.sendEmailVerification();

  Future<void> reloadUser() => _authService.reloadUser();

  /// Envoie un email de réinitialisation de mot de passe.
  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authService.sendPasswordResetEmail(email),
    );
  }

  /// Referme la session après avoir retiré le jeton de notification : sans
  /// cela, la personne suivante à utiliser cet appareil recevrait les
  /// notifications de la précédente.
  Future<void> signOut() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      try {
        await _messagingService.unregisterDevice(uid);
      } catch (_) {
        // Un jeton qui résiste ne doit pas empêcher de se déconnecter.
      }
    }
    await _authService.signOut();
  }

  /// Supprime le compte puis referme la session. Le router ramène alors
  /// automatiquement vers l'écran de connexion.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _accountService.deleteAccount();
      await _authService.signOut();
    });
  }
}

final accountServiceProvider =
    Provider<AccountService>((ref) => AccountService());

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    ref.watch(authServiceProvider),
    ref.watch(accountServiceProvider),
    ref.watch(messagingServiceProvider),
  );
});
