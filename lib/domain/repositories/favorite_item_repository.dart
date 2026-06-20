import '../entities/favorite_item.dart';

/// よく買う物テンプレート（`groups/{groupId}/favoriteItems/{favoriteId}`）の永続化抽象。
abstract class FavoriteItemRepository {
  /// よく買う物テンプレートをリアルタイム購読する（order 昇順）。
  Stream<List<FavoriteItem>> watchFavorites(String groupId);

  /// よく買う物テンプレートを追加する。
  ///
  /// @param draft 追加するテンプレート（id は無視され、createdAt はサーバ時刻で設定される）
  /// @param order リスト末尾に追加するための順序値（既存最大 order + 1）
  /// @returns 生成されたドキュメント ID
  Future<String> addFavorite(String groupId, FavoriteItem draft, int order);

  /// よく買う物テンプレートの詳細（名前・タグ・メモ・写真）を更新する。
  ///
  /// 各パラメータは省略可能で、指定したフィールドのみ更新される。
  /// [tagId] は以下のように動作する:
  ///   - `tagId: 'xxx'` → タグを設定する
  ///   - `tagId: () => null` → タグを解除する（フィールド削除）
  ///   - 省略 → tagId を変更しない
  Future<void> updateFavorite(
    String groupId,
    String id, {
    String? name,
    String? Function()? tagId,
    String? note,
    String? imageUrl,
  });

  /// 指定のよく買う物テンプレートを削除する。
  Future<void> deleteFavorite(String groupId, String id);
}
