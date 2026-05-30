/// ユーザードキュメント（`users/{uid}`）のドメインモデル。
///
/// 元の `UserDoc` 型を移植。イミュータブルとし、変更は [copyWith] で新インスタンスを生成する。
class UserDoc {
  const UserDoc({
    required this.displayName,
    required this.avatarUrl,
    required this.groupId,
    required this.notificationsEnabled,
    required this.fcmToken,
    this.createdAt,
  });

  final String displayName;
  final String avatarUrl;
  final String? groupId;
  final bool notificationsEnabled;
  final String? fcmToken;
  final DateTime? createdAt;

  UserDoc copyWith({
    String? displayName,
    String? avatarUrl,
    String? Function()? groupId,
    bool? notificationsEnabled,
    String? Function()? fcmToken,
    DateTime? createdAt,
  }) {
    return UserDoc(
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      groupId: groupId != null ? groupId() : this.groupId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fcmToken: fcmToken != null ? fcmToken() : this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
