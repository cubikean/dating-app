import 'package:firebase_auth/firebase_auth.dart';

/// Encapsule Firebase Auth. Les providers Riverpod dépendent de cette
/// classe plutôt que d'appeler `FirebaseAuth.instance` directement,
/// ce qui facilite les tests (mock de `AuthService`).
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  // TODO: ajouter signInWithGoogle() via google_sign_in si besoin d'auth sociale.
}
