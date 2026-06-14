/// グループ（`groups/{groupId}`）のドメインモデル。
///
/// 元の `GroupDoc & { id }` を統合した型。イミュータブル。
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.inviteCode,
    this.createdAt,
    this.plan,
  });

  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final String inviteCode;
  final DateTime? createdAt;

  /// 料金プラン（`'free'` / `'paid'`。未設定時は free 相当）。
  ///
  /// クライアントは読み取りのみ。書き込みは Functions / RevenueCat Webhook
  /// （Admin SDK）に限定され、`firestore.rules` でクライアントからの
  /// `plan` / `planExpiresAt` の変更を禁止している（#39 マネタイズ M0）。
  final String? plan;

  /// 指定 uid がこのグループのオーナーかどうか。
  bool isOwnedBy(String uid) => ownerId == uid;

  /// 指定 uid がメンバーに含まれるかどうか。
  bool hasMember(String uid) => memberIds.contains(uid);

  Group copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? memberIds,
    String? inviteCode,
    DateTime? createdAt,
    String? plan,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      plan: plan ?? this.plan,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Group &&
      other.id == id &&
      other.name == name &&
      other.ownerId == ownerId &&
      other.inviteCode == inviteCode &&
      other.plan == plan &&
      _listEquals(other.memberIds, memberIds);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ownerId,
    inviteCode,
    plan,
    Object.hashAll(memberIds),
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
