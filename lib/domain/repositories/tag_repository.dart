import '../entities/tag.dart';

/// タグ（`groups/{groupId}/tags/{tagId}`）の永続化抽象。
abstract class TagRepository {
  /// タグを追加する。
  ///
  /// @param order リスト末尾に追加するための順序値（既存最大 order + 1）。呼び出し元が計算して渡す。
  /// @returns 生成されたタグ（ID 付き）
  Future<Tag> addTag(String groupId, String name, int order);

  /// タグ名を更新する。
  Future<void> updateTagName(String groupId, String tagId, String name);

  /// タグを削除し、そのタグを参照するアイテムの tagId を同一バッチでクリアする。
  Future<void> deleteTagAndClearItems(String groupId, String tagId);

  /// 現在のタグ件数を取得する（プラン上限チェック用）。
  Future<int> getTagsCount(String groupId);

  /// タグコレクションをリアルタイム購読する（order 昇順）。
  Stream<List<Tag>> watchTags(String groupId);
}
