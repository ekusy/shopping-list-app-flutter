import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_error.dart';

/// Firebase Auth の error code → [AppErrorCode] マッピング。
///
/// FlutterFire の `FirebaseAuthException.code` は `auth/` プレフィックスを持たない
/// （例: `invalid-credential`）。SDK で統合された `user-not-found` / `wrong-password` は
/// `invalid-credential` に寄せる。
const Map<String, AppErrorCode> _authCodeMap = {
  'email-already-in-use': AppErrorCode.authEmailAlreadyInUse,
  'weak-password': AppErrorCode.authWeakPassword,
  'invalid-email': AppErrorCode.authInvalidEmail,
  'invalid-credential': AppErrorCode.authInvalidCredential,
  'user-not-found': AppErrorCode.authInvalidCredential,
  'wrong-password': AppErrorCode.authInvalidCredential,
  'too-many-requests': AppErrorCode.authTooManyRequests,
  'network-request-failed': AppErrorCode.authNetworkRequestFailed,
};

/// Firestore / Storage の error code → [AppErrorCode] マッピング。
const Map<String, AppErrorCode> _firestoreCodeMap = {
  'permission-denied': AppErrorCode.dataPermissionDenied,
  'not-found': AppErrorCode.dataNotFound,
  'unavailable': AppErrorCode.dataUnavailable,
  'resource-exhausted': AppErrorCode.dataResourceExhausted,
};

/// 任意の例外を [AppError] に変換する。
///
/// UI 層から Firebase 依存を隔離するための唯一の変換点。
/// Repository 層の catch で本関数を通してから rethrow する。
AppError toAppError(Object e) {
  if (e is AppError) return e;
  if (e is FirebaseAuthException) {
    final code = e.code.replaceFirst('auth/', '');
    return AppError(
      _authCodeMap[code] ?? AppErrorCode.authUnknown,
      e.message ?? e.code,
      e,
    );
  }
  if (e is FirebaseException) {
    return AppError(
      _firestoreCodeMap[e.code] ?? AppErrorCode.dataUnknown,
      e.message ?? e.code,
      e,
    );
  }
  return AppError(AppErrorCode.dataUnknown, e.toString(), e);
}
