/// 各入力フィールドの文字数上限定数。
///
/// UI の `maxLength` と書き込み前バリデーション双方で参照する。
/// 元の `src/constants/validationLimits.ts` を移植。
class ValidationLimits {
  ValidationLimits._();

  /// グループ名の最大文字数。
  static const int groupName = 50;

  /// ユーザー名（表示名）の最大文字数。
  static const int displayName = 30;

  /// リスト名の最大文字数。
  static const int listName = 50;

  /// アイテム名の最大文字数。
  static const int itemName = 100;

  /// アイテムメモの最大文字数。
  static const int itemNote = 200;

  /// タグ名の最大文字数。
  static const int tagName = 20;
}
