/// カードアクションに使用するアイコン設定。
///
/// 元の `src/lib/itemIcons.ts` の `ItemIconConfig` を移植。絵文字を文字列で保持する。
class ItemIconConfig {
  const ItemIconConfig({
    required this.volunteer,
    required this.cancelVolunteer,
    required this.takeOver,
    required this.bought,
    required this.returnToBuy,
    required this.delete,
    required this.pendingSync,
    required this.volunteerBadge,
    required this.othersBadge,
  });

  /// 買うよ宣言ボタン。
  final String volunteer;

  /// 担当解除ボタン。
  final String cancelVolunteer;

  /// 代わりに買うボタン（他人が宣言中）。
  final String takeOver;

  /// 購入済みボタン。
  final String bought;

  /// 未購入に戻すボタン。
  final String returnToBuy;

  /// 削除ボタン。
  final String delete;

  /// 同期待ちアイコン。
  final String pendingSync;

  /// 自分が買いますバッジのアイコン。
  final String volunteerBadge;

  /// 他人が買いますバッジのアイコン。
  final String othersBadge;
}

/// デフォルトのアイコンセット。
const ItemIconConfig _defaultIcons = ItemIconConfig(
  // 🙋 = 挙手（担当する意思表示）。🛒 はカート＝購入済みと混同されるため不使用。
  volunteer: '🙋',
  cancelVolunteer: '✕',
  takeOver: '🔄',
  bought: '✅',
  returnToBuy: '↩',
  delete: '🗑️',
  pendingSync: '⏳',
  volunteerBadge: '🙋',
  othersBadge: '👤',
);

/// 言語別アイコンオーバーライド（必要に応じて追加）。
const Map<String, ItemIconConfig> _iconOverridesByLanguage = {};

/// 指定言語に対応するアイコンセットを返す。
///
/// 言語固有のオーバーライドがある場合はそれを返し、なければデフォルトを返す。
///
/// @param language 言語コード（例: 'ja', 'en'）
/// @returns アイコン設定
ItemIconConfig getItemIcons(String language) {
  return _iconOverridesByLanguage[language] ?? _defaultIcons;
}
