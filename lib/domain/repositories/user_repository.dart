import '../entities/user_doc.dart';

/// ユーザードキュメント（`users/{uid}`）の永続化抽象。
abstract class UserRepository {
  /// サインアップ直後に初期プロフィールドキュメントを作成する。
  Future<void> createUserDocument(String uid);

  /// `groupId` フィールドを更新する。
  Future<void> updateUserGroupId(String uid, String groupId);

  /// 表示名・アバター URL を更新する（指定したフィールドのみ）。
  Future<void> updateUserProfile(
    String uid, {
    String? displayName,
    String? avatarUrl,
  });

  /// ユーザードキュメントを物理削除する。
  Future<void> deleteUserDocument(String uid);

  /// ユーザープロフィールを取得する（未存在は null）。
  Future<UserDoc?> getUserProfile(String uid);

  /// 通知設定フラグを更新する。
  Future<void> updateNotificationEnabled(String uid, bool enabled);

  /// ユーザードキュメントをリアルタイム購読する（未存在は null）。
  Stream<UserDoc?> watchUser(String uid);

  /// `groupId` フィールドを取得する（未所属・未存在は null）。
  Future<String?> getUserGroupId(String uid);
}
