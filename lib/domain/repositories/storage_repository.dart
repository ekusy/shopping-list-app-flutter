import 'dart:typed_data';

/// 画像ストレージ（Firebase Storage）への抽象。
abstract class StorageRepository {
  /// アバター画像をアップロードしてダウンロード URL を返す。
  ///
  /// @param uid 対象ユーザーの uid（保存パス `avatars/{uid}` に使用）
  /// @param bytes アップロードする画像バイト列
  /// @returns ダウンロード URL
  Future<String> uploadAvatar(String uid, Uint8List bytes);

  /// アイテム画像を Firebase Storage にアップロードしてダウンロード URL を返す。
  ///
  /// パス: `groups/{groupId}/items/{itemId}.jpg`
  /// Cache-Control メタデータ（`public, max-age=31536000`）を付与する。
  ///
  /// @param groupId グループ ID
  /// @param itemId アイテム ID
  /// @param bytes アップロードする JPEG バイト列
  /// @returns ダウンロード URL
  Future<String> uploadItemImage(
    String groupId,
    String itemId,
    Uint8List bytes,
  );

  /// アイテム画像を Firebase Storage から削除する（best-effort）。
  ///
  /// ファイルが存在しない場合もエラーとしない。
  ///
  /// @param groupId グループ ID
  /// @param itemId アイテム ID
  Future<void> deleteItemImage(String groupId, String itemId);
}
