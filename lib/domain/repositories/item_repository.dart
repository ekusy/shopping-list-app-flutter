import '../entities/item.dart';

/// アイテム（`groups/{groupId}/items/{itemId}`）の永続化抽象。
///
/// 元の汎用 `updateItem(Partial<ItemDoc>)` を、意図が明確なメソッドに分割している。
abstract class ItemRepository {
  /// アイテムを追加する。
  ///
  /// @param draft 追加するアイテム（id は無視され、createdAt はサーバ時刻で設定される）
  /// @param order リスト末尾に追加するための順序値（既存最大 order + 1）
  /// @returns 生成されたドキュメント ID
  Future<String> addItem(String groupId, Item draft, int order);

  /// 「買います」宣言者を設定する。
  ///
  /// @param uid 宣言者の uid。null で宣言を取り消す。
  Future<void> setVolunteer(String groupId, String itemId, String? uid);

  /// 購入済み / 未購入を切り替える。
  Future<void> setPurchased(String groupId, String itemId, bool purchased);

  /// アイテムの詳細（名前・タグ・メモ・写真）を更新する。
  ///
  /// @param tagId 設定するタグ ID。null でタグを解除する。
  Future<void> updateItemDetails(
    String groupId,
    String itemId, {
    required String name,
    String? tagId,
    required String note,
    required String imageUrl,
  });

  /// 指定アイテムを削除する。
  Future<void> deleteItem(String groupId, String itemId);

  /// 購入済みアイテムを一括削除する。
  Future<void> deletePurchasedItems(String groupId);

  /// 指定タグ ID を持つアイテムを一括削除する。
  Future<void> deleteItemsByTag(String groupId, String tagId);

  /// 複数アイテムのタグ ID を一括更新する。
  ///
  /// @param tagId 設定するタグ ID。null でタグを解除する。
  Future<void> batchUpdateTag(
    String groupId,
    List<String> itemIds,
    String? tagId,
  );

  /// アイテムコレクションをリアルタイム購読する。
  /// order 昇順優先、未設定時は createdAt 降順でソートして返す。
  Stream<List<Item>> watchItems(String groupId);
}
