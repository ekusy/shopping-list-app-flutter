/// タグ（`groups/{groupId}/tags/{tagId}`）のドメインモデル。
///
/// グループ内で共有されるラベル。元の `TagDoc & { id }` を統合した型。
class Tag {
  const Tag({
    required this.id,
    required this.name,
    this.createdAt,
    this.order,
  });

  final String id;
  final String name;
  final DateTime? createdAt;

  /// 表示順（数値が小さいほど上位。未設定時は createdAt 昇順）。
  final int? order;

  Tag copyWith({String? id, String? name, DateTime? createdAt, int? order}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Tag &&
      other.id == id &&
      other.name == name &&
      other.order == order;

  @override
  int get hashCode => Object.hash(id, name, order);
}
