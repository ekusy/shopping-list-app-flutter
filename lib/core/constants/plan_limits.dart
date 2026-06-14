/// プランごとの上限値の定義。
///
/// 元の `src/constants/planLimits.ts` の `TAG_LIMIT = { free: 5, paid: 50 }` を移植。
///
/// 今後追加される上限（よく買う物 #43 / 写真 #38 / 同時参加グループ数 /
/// グループメンバー上限 等）も、マジック値の散在を防ぐためここに集約すること
/// （#39 マネタイズ M0）。
class PlanLimits {
  PlanLimits._();

  /// 無料プランを表すプラン文字列。
  static const String planFree = 'free';

  /// 有料プランを表すプラン文字列。
  static const String planPaid = 'paid';

  /// 無料プランのタグ上限。
  static const int freeTagLimit = 5;

  /// 有料プランのタグ上限。
  static const int paidTagLimit = 50;

  /// プラン文字列（未設定時は free 扱い）からタグ上限を返す。
  ///
  /// @param plan グループの料金プラン（`'free'` / `'paid'` / null）
  /// @returns タグ上限件数
  static int tagLimitFor(String? plan) =>
      plan == planPaid ? paidTagLimit : freeTagLimit;
}
