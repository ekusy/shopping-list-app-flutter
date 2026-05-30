import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../firebase/firebase_error_converter.dart';

/// Firebase Authentication を用いた [AuthRepository] 実装。
///
/// すべての Firebase 例外は [toAppError] で `AppError` に変換してから throw する。
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  AuthUser? _toAuthUser(User? u) =>
      u == null ? null : AuthUser(uid: u.uid, email: u.email);

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<AuthUser> signUp(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toAuthUser(cred.user)!;
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toAuthUser(cred.user)!;
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      throw toAppError(e);
    }
  }
}
