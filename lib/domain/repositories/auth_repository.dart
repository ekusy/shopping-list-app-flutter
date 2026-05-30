import '../entities/auth_user.dart';

/// 認証バックエンド（Firebase Auth）への薄いアクセス抽象。
///
/// 実装を差し替えることでテスト時のモック化・将来のバックエンド移行を可能にする。
/// ユーザードキュメント作成やアバターアップロード等のオーケストレーションは
/// 上位（presentation の AuthController）が担う。
abstract class AuthRepository {
  /// 認証状態の変更ストリーム（ログアウト時は null）。
  Stream<AuthUser?> authStateChanges();

  /// 現在の認証ユーザー（未ログイン時は null）。
  AuthUser? get currentUser;

  /// メール + パスワードで新規登録し、作成されたユーザーを返す。
  Future<AuthUser> signUp(String email, String password);

  /// メール + パスワードでログインし、ユーザーを返す。
  Future<AuthUser> signIn(String email, String password);

  /// ログアウトする。
  Future<void> signOut();

  /// 現在の認証ユーザーを削除する（Firebase Auth 上のアカウント削除）。
  Future<void> deleteCurrentUser();
}
