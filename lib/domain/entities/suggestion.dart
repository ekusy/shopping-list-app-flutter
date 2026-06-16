/// AI 提案の confidence レベル（`forgottenItems` 各要素）。
enum SuggestionConfidence {
  high('high'),
  medium('medium'),
  low('low');

  const SuggestionConfidence(this.code);

  /// Firestore に保存される文字列値。
  final String code;

  /// 文字列コードから [SuggestionConfidence] を解決する（未知の値は [low] にフォールバック）。
  static SuggestionConfidence fromCode(String? code) {
    for (final c in SuggestionConfidence.values) {
      if (c.code == code) return c;
    }
    return SuggestionConfidence.low;
  }
}

/// AI 提案ドキュメントのステータス。
enum SuggestionStatus {
  ready('ready'),
  empty('empty');

  const SuggestionStatus(this.code);

  /// Firestore に保存される文字列値。
  final String code;

  /// 文字列コードから [SuggestionStatus] を解決する（未知の値は [empty] にフォールバック）。
  static SuggestionStatus fromCode(String? code) {
    for (final s in SuggestionStatus.values) {
      if (s.code == code) return s;
    }
    return SuggestionStatus.empty;
  }
}

/// `groups/{groupId}/suggestions/{weekId}` の `forgottenItems` 各要素。
class ForgottenItem {
  const ForgottenItem({
    required this.name,
    required this.reason,
    required this.confidence,
  });

  final String name;
  final String reason;
  final SuggestionConfidence confidence;
}

/// `groups/{groupId}/suggestions/{weekId}` の `recommendedItems` 各要素。
class RecommendedItem {
  const RecommendedItem({required this.name, required this.reason});

  final String name;
  final String reason;
}

/// `groups/{groupId}/suggestions/{weekId}` のドメインモデル。
///
/// [id] は Firestore ドキュメント ID（ISO week id, e.g. `'2026-W24'`）。
class Suggestion {
  const Suggestion({
    required this.id,
    required this.generatedAt,
    required this.status,
    required this.forgottenItems,
    required this.recommendedItems,
  });

  /// Firestore ドキュメント ID（= weekId, e.g. `'2026-W24'`）。
  final String id;

  /// 提案生成日時。
  final DateTime generatedAt;

  /// ステータス（ready / empty）。
  final SuggestionStatus status;

  /// 購入忘れかもリスト（confidence 降順: high → medium → low）。
  final List<ForgottenItem> forgottenItems;

  /// 次の買い物におすすめリスト。
  final List<RecommendedItem> recommendedItems;
}
