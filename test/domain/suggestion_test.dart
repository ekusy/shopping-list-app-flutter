import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/suggestion.dart';

void main() {
  group('SuggestionStatus.fromCode', () {
    test('ready を解決する', () {
      expect(SuggestionStatus.fromCode('ready'), SuggestionStatus.ready);
    });

    test('empty を解決する', () {
      expect(SuggestionStatus.fromCode('empty'), SuggestionStatus.empty);
    });

    test('未知の値は empty にフォールバックする', () {
      expect(SuggestionStatus.fromCode('unknown'), SuggestionStatus.empty);
      expect(SuggestionStatus.fromCode(null), SuggestionStatus.empty);
    });
  });

  group('SuggestionConfidence.fromCode', () {
    test('high を解決する', () {
      expect(SuggestionConfidence.fromCode('high'), SuggestionConfidence.high);
    });

    test('medium を解決する', () {
      expect(
        SuggestionConfidence.fromCode('medium'),
        SuggestionConfidence.medium,
      );
    });

    test('low を解決する', () {
      expect(SuggestionConfidence.fromCode('low'), SuggestionConfidence.low);
    });

    test('未知の値は low にフォールバックする', () {
      expect(
        SuggestionConfidence.fromCode('invalid'),
        SuggestionConfidence.low,
      );
      expect(SuggestionConfidence.fromCode(null), SuggestionConfidence.low);
    });
  });

  group('Suggestion コンストラクタ', () {
    test('フィールドが正しく格納される', () {
      final now = DateTime(2026, 6, 14);
      final s = Suggestion(
        id: '2026-W24',
        generatedAt: now,
        status: SuggestionStatus.ready,
        forgottenItems: [
          const ForgottenItem(
            name: '牛乳',
            reason: '先週買い忘れた',
            confidence: SuggestionConfidence.high,
          ),
        ],
        recommendedItems: [const RecommendedItem(name: '卵', reason: '毎週買っている')],
      );

      expect(s.id, '2026-W24');
      expect(s.generatedAt, now);
      expect(s.status, SuggestionStatus.ready);
      expect(s.forgottenItems.length, 1);
      expect(s.forgottenItems.first.name, '牛乳');
      expect(s.forgottenItems.first.confidence, SuggestionConfidence.high);
      expect(s.recommendedItems.length, 1);
      expect(s.recommendedItems.first.name, '卵');
    });

    test('空リストで構築できる', () {
      final s = Suggestion(
        id: '2026-W24',
        generatedAt: DateTime.now(),
        status: SuggestionStatus.empty,
        forgottenItems: const [],
        recommendedItems: const [],
      );

      expect(s.forgottenItems, isEmpty);
      expect(s.recommendedItems, isEmpty);
    });
  });
}
