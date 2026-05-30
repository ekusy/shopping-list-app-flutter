/// アプリ内で扱う認証ユーザー（Firebase `User` のサブセット）。
///
/// UI 層・状態管理層から Firebase 固有型への依存を切り離すための正規化型。
/// 元の `AuthUser` 型を移植。
class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}
