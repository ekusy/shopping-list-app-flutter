/// アイテムの購入ステータス。
///
/// `'buying'` 値は存在せず、「買います」中は [Item.buyingBy] が非 null の論理状態で表す。
enum ItemStatus {
  active('active'),
  purchased('purchased');

  const ItemStatus(this.code);

  /// Firestore に保存される文字列値。
  final String code;

  /// 文字列コードから [ItemStatus] を解決する（未知の値は null）。
  static ItemStatus? fromCode(String? code) {
    for (final s in ItemStatus.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// アイテム（`groups/{groupId}/items/{itemId}`）のドメインモデル。
///
/// #142 でリストを廃止しフラット構造に移行。旧フィールド（[isBought] / [buyerId]）との
/// 互換を保つため新旧両方を保持する。元の `ItemDoc & ItemWithId` を統合。
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.category,
    required this.note,
    required this.imageUrl,
    this.createdAt,
    this.addedBy,
    this.order,
    this.status,
    this.buyingBy,
    this.isBought,
    this.buyerId,
    this.tagId,
    this.pendingWrite = false,
  });

  final String id;
  final String name;
  final String category;
  final String note;
  final String imageUrl;
  final DateTime? createdAt;
  final String? addedBy;

  /// 並べ替え順（数値が小さいほど上に表示。未設定時は createdAt でソート）。
  final int? order;

  // --- 新フィールド ---
  final ItemStatus? status;
  final String? buyingBy;

  // --- 旧フィールド（フォールバック用） ---
  final bool? isBought;
  final String? buyerId;

  /// タグ ID（未設定はタグなし）。
  final String? tagId;

  /// Firestore 未同期書き込みフラグ（オフライン時のローカル更新で true）。
  /// 永続化されず、`metadata.hasPendingWrites` から派生して付与する。
  final bool pendingWrite;

  /// 購入済みかどうか（新フィールド優先、旧フィールドをフォールバック）。
  bool get isPurchased => status == ItemStatus.purchased || isBought == true;

  /// 「買います」宣言者の uid（新フィールド優先、旧フィールドをフォールバック）。
  String? get volunteerUid => buyingBy ?? buyerId;

  /// 誰かが「買います」宣言中かどうか。
  bool get isBeingBought => volunteerUid != null;

  Item copyWith({
    String? id,
    String? name,
    String? category,
    String? note,
    String? imageUrl,
    DateTime? createdAt,
    String? addedBy,
    int? order,
    ItemStatus? status,
    String? Function()? buyingBy,
    bool? isBought,
    String? buyerId,
    String? Function()? tagId,
    bool? pendingWrite,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
      order: order ?? this.order,
      status: status ?? this.status,
      buyingBy: buyingBy != null ? buyingBy() : this.buyingBy,
      isBought: isBought ?? this.isBought,
      buyerId: buyerId ?? this.buyerId,
      tagId: tagId != null ? tagId() : this.tagId,
      pendingWrite: pendingWrite ?? this.pendingWrite,
    );
  }
}
