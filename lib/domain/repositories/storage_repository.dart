import 'dart:typed_data';

/// 画像ストレージ（Firebase Storage）への抽象。
abstract class StorageRepository {
  /// アバター画像をアップロードしてダウンロード URL を返す。
  ///
  /// @param uid 対象ユーザーの uid（保存パス `avatars/{uid}` に使用）
  /// @param bytes アップロードする画像バイト列
  /// @returns ダウンロード URL
  Future<String> uploadAvatar(String uid, Uint8List bytes);
}
