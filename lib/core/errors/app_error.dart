/// アプリ全体で扱うエラーコード（ドメイン別 union）。
///
/// 元の `src/types/errors.ts` の文字列リテラル union を型安全な enum に移植したもの。
/// 各値は元コードと同一の文字列（`auth/...` / `data/...` / `group/...`）を [code] に保持する。
enum AppErrorCode {
  // --- 認証レイヤー (AuthErrorCode) ---
  authEmailAlreadyInUse('auth/email-already-in-use'),
  authWeakPassword('auth/weak-password'),
  authInvalidEmail('auth/invalid-email'),
  authInvalidCredential('auth/invalid-credential'),
  authTooManyRequests('auth/too-many-requests'),
  authUserNotFound('auth/user-not-found'),
  authNetworkRequestFailed('auth/network-request-failed'),
  authCannotDeleteOwner('auth/cannot-delete-owner'),
  authUnknown('auth/unknown'),

  // --- データアクセスレイヤー (DataErrorCode) ---
  dataPermissionDenied('data/permission-denied'),
  dataNotFound('data/not-found'),
  dataUnavailable('data/unavailable'),
  dataResourceExhausted('data/resource-exhausted'),
  dataTagLimitExceeded('data/tag-limit-exceeded'),
  dataUnknown('data/unknown'),

  // --- グループ管理レイヤー (GroupErrorCode) ---
  groupOwnerCannotLeave('group/owner-cannot-leave'),
  groupInvalidInviteCode('group/invalid-invite-code'),
  groupAlreadyMember('group/already-member'),
  groupCannotRemoveOwner('group/cannot-remove-owner');

  const AppErrorCode(this.code);

  /// 元実装と互換性のある文字列コード（例: `auth/invalid-credential`）。
  final String code;
}

/// アプリ層で投げる統一エラー。
///
/// UI 層は [code] で分岐し、元となった例外（[FirebaseException] 等）は [cause] に保持する。
/// Firebase 固有の例外は Service / Repository 層の `toAppError()` で本型に変換してから throw する。
class AppError implements Exception {
  /// @param code アプリ固有のエラーコード
  /// @param message デバッグ用メッセージ（UI 文言には使わない）
  /// @param cause 元となった例外（FirebaseException 等）
  const AppError(this.code, this.message, [this.cause]);

  final AppErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppError(${code.code}): $message';
}
