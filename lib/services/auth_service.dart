import 'package:firebase_auth/firebase_auth.dart';

/// Encapsule Firebase Auth. Les providers Riverpod dépendent de cette
/// classe plutôt que d'appeler `FirebaseAuth.instance` directement,
/// ce qui facilite les tests (mock de `AuthService`).
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Comme `authStateChanges`, mais émet aussi quand l'utilisateur est
  /// rechargé. C'est le seul moyen de voir passer `emailVerified` à vrai :
  /// la vérification se fait dans un navigateur, hors de l'application.
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Redemande l'état du compte au serveur. Sans cet appel, `emailVerified`
  /// reste à sa valeur du moment de la connexion.
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  // TODO: ajouter signInWithGoogle() via google_sign_in si besoin d'auth sociale.
}
