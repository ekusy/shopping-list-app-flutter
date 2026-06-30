import '../entities/purchase_history_entry.dart';

/// 購入履歴（`groups/{groupId}/itemHistory`）の読み取り抽象。
///
/// 履歴は Cloud Functions が書き込むためクライアントは読み取り専用。リアルタイム購読は
/// 不要で、`get` ベースのページングで十分（#42 Step 1）。
abstract class HistoryRepository {
  /// 購入イベント（`type == 'purchased'`）を `occurredAt` 降順で 1 ページ取得する。
  ///
  /// @param limit 取得件数の上限。
  /// @param before 非 null の場合、この日時より前（より古い）から取得する（カーソル）。
  ///   通常は直前ページ末尾の [PurchaseHistoryEntry.occurredAt] を渡す。
  Future<List<PurchaseHistoryEntry>> fetchPurchases(
    String groupId, {
    required int limit,
    DateTime? before,
  });
}
