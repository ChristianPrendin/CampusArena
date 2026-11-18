import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over [FirebaseAuth]. Surfaces only the operations the auth flow
/// needs and rethrows [FirebaseAuthException] for `AuthCubit` to map to error
/// states — no domain-exception layer.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Emits on every sign-in / sign-out; drives the app's auth gate.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// The currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
