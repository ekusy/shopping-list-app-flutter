/// 購入履歴の 1 イベント（`groups/{groupId}/itemHistory` の `type == 'purchased'`）。
///
/// 履歴は Cloud Functions（#37 Phase 0）が書き込み、クライアントは読み取りのみ。
/// 生イベントは TTL（180 日）で消えるため、タイムラインは「直近 6 ヶ月」を表示する。
/// Step 1（#42）では `purchased` イベントのみを扱い、`deleted` は表示しない。
class PurchaseHistoryEntry {
  const PurchaseHistoryEntry({
    required this.id,
    required this.itemId,
    required this.name,
    this.tagId,
    this.purchasedBy,
    required this.occurredAt,
  });

  /// itemHistory ドキュメント ID。
  final String id;

  /// 購入された元アイテムの ID（再追加時の参照用）。
  final String itemId;

  /// 商品名。
  final String name;

  /// 購入時に紐づいていたタグ ID（再追加でタグを復元するために保持）。
  final String? tagId;

  /// 購入者の uid（`buyingBy ?? buyerId`）。未設定の場合あり。
  final String? purchasedBy;

  /// 購入が記録された日時。
  final DateTime occurredAt;
}
