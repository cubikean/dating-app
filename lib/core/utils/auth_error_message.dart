import 'package:firebase_auth/firebase_auth.dart';

/// Traduit une erreur d'authentification en message lisible par l'utilisateur.
///
/// Depuis l'activation par défaut de la protection contre l'énumération des
/// emails, Firebase fusionne `user-not-found` et `wrong-password` en un seul
/// code `invalid-credential` : on ne peut donc pas distinguer les deux cas.
String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Une erreur est survenue. Réessaie dans un instant.';
  }

  // App Check est appliqué côté serveur : le refus arrive avec un code
  // d'erreur générique mais un message explicite, d'où ce test sur le texte.
  if ((error.message ?? '').contains('App Check')) {
    return "L'application n'est pas reconnue par Firebase. Au démarrage, "
        'fournis la clé reCAPTCHA : --dart-define=RECAPTCHA_SITE_KEY=…';
  }

  switch (error.code) {
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'user-not-found':
    case 'wrong-password':
      return 'Email ou mot de passe incorrect.';
    case 'invalid-email':
      return "L'adresse email n'est pas valide.";
    case 'user-disabled':
      return 'Ce compte a été désactivé.';
    case 'email-already-in-use':
      return 'Un compte existe déjà avec cet email.';
    case 'weak-password':
      return 'Mot de passe trop faible (6 caractères minimum).';
    case 'operation-not-allowed':
      return "La connexion par email n'est pas activée sur ce projet.";
    case 'too-many-requests':
      return 'Trop de tentatives. Réessaie dans quelques minutes.';
    case 'network-request-failed':
      return 'Connexion réseau impossible. Vérifie ta connexion.';
    default:
      return error.message ?? 'Authentification impossible.';
  }
}
