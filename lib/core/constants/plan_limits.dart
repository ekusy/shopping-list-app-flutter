/// プランごとのタグ上限数。
///
/// 元の `src/constants/planLimits.ts` の `TAG_LIMIT = { free: 5, paid: 50 }` を移植。
class PlanLimits {
  PlanLimits._();

  /// 無料プランのタグ上限。
  static const int freeTagLimit = 5;

  /// 有料プランのタグ上限。
  static const int paidTagLimit = 50;

  /// プラン文字列（未設定時は free 扱い）からタグ上限を返す。
  ///
  /// @param plan グループの料金プラン（`'free'` / `'paid'` / null）
  /// @returns タグ上限件数
  static int tagLimitFor(String? plan) =>
      plan == 'paid' ? paidTagLimit : freeTagLimit;
}
