import '../entities/group.dart';

/// グループ作成結果（グループ ID と招待コード）。
typedef CreateGroupResult = ({String groupId, String inviteCode});

/// グループ（`groups/{groupId}`）の永続化抽象。
abstract class GroupRepository {
  /// グループを新規作成する。
  ///
  /// バッチで「groups 作成 + デフォルトタグ作成 + users.groupId 更新」を一括コミットする。
  ///
  /// @param uid 作成者の uid
  /// @param groupName グループ名
  /// @param defaultTagNames グループ作成時に自動生成するタグ名（表示言語に合わせて呼び出し元で生成）
  /// @returns 作成されたグループ ID と招待コード
  Future<CreateGroupResult> createGroup(
    String uid,
    String groupName,
    List<String> defaultTagNames,
  );

  /// uid がいずれかのグループのオーナーかどうか。
  Future<bool> isGroupOwner(String uid);

  /// グループを取得する（未存在は null）。
  Future<Group?> getGroup(String groupId);

  /// uid が memberIds に含まれるグループを全件取得する。
  Future<List<Group>> getGroupsByMemberId(String uid);

  /// グループ名を更新する。
  Future<void> updateGroupName(String groupId, String name);

  /// メンバーがグループから脱退する（memberIds から uid 除去 + users.groupId=null）。
  /// オーナーシップ判定は呼び出し元が行うこと。
  Future<void> leaveGroup(String uid, String groupId);

  /// オーナーがグループを解散する。
  Future<void> disbandGroup(String uid, String groupId);

  /// 招待コードでグループを検索する（未存在は null）。
  Future<Group?> getGroupByInviteCode(String inviteCode);

  /// 招待コードでグループに参加する。
  ///
  /// @returns 参加したグループ ID
  /// @throws AppError(groupInvalidInviteCode) コードが存在しない場合
  /// @throws AppError(groupAlreadyMember) すでに参加済みの場合
  Future<String> joinGroup(String uid, String inviteCode);

  /// オーナーが指定メンバーを強制退場させる。
  ///
  /// @throws AppError(groupCannotRemoveOwner) targetUid がオーナーの場合
  /// @throws AppError(dataNotFound) グループが存在しない場合
  Future<void> removeMember(String groupId, String targetUid);

  /// グループドキュメントをリアルタイム購読する（未存在は null）。
  Stream<Group?> watchGroup(String groupId);
}
