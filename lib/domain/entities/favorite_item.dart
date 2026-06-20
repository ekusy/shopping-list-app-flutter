/// よく買う物テンプレート（`groups/{groupId}/favoriteItems/{favoriteId}`）のドメインモデル。
///
/// グループ単位で保持するアイテムテンプレート集。[Item] とは異なり、
/// 購入状態や「買います」宣言など「リスト上の状態」フィールドは持たない。
class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.name,
    required this.note,
    required this.imageUrl,
    required this.order,
    required this.addedBy,
    this.tagId,
    this.createdAt,
  });

  final String id;
  final String name;

  /// タグ ID（未設定はタグなし）。
  final String? tagId;

  final String note;
  final String imageUrl;

  /// 表示順（数値が小さいほど上位）。
  final int order;

  final DateTime? createdAt;
  final String addedBy;

  FavoriteItem copyWith({
    String? id,
    String? name,
    String? Function()? tagId,
    String? note,
    String? imageUrl,
    int? order,
    DateTime? createdAt,
    String? addedBy,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      name: name ?? this.name,
      tagId: tagId != null ? tagId() : this.tagId,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FavoriteItem &&
      other.id == id &&
      other.name == name &&
      other.tagId == tagId &&
      other.note == note &&
      other.imageUrl == imageUrl &&
      other.order == order &&
      other.addedBy == addedBy;

  @override
  int get hashCode =>
      Object.hash(id, name, tagId, note, imageUrl, order, addedBy);
}
