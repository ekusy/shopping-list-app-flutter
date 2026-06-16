import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/suggestion.dart';
import 'package:shopping_list_app/presentation/providers/suggestion_providers.dart';

Suggestion _suggestion({
  String id = '2026-W24',
  SuggestionStatus status = SuggestionStatus.ready,
}) => Suggestion(
  id: id,
  generatedAt: DateTime(2026, 6, 14, 8),
  status: status,
  forgottenItems: const [],
  recommendedItems: const [],
);

void main() {
  // 未読バッジ判定の純粋ロジック（hasUnreadSuggestionProvider の中核）を直接検証する。
  // provider 本体は latestSuggestionProvider(.value) と SharedPreferences を読むだけの
  // 薄いグルーであり、判定はこの関数に集約されている。
  group('isSuggestionUnread', () {
    test('提案なし（null）→ false', () {
      expect(isSuggestionUnread(null, null), isFalse);
    });

    test('status: empty → false', () {
      expect(
        isSuggestionUnread(_suggestion(status: SuggestionStatus.empty), null),
        isFalse,
      );
    });

    test('ready かつ既読なし → true', () {
      expect(isSuggestionUnread(_suggestion(id: '2026-W24'), null), isTrue);
    });

    test('ready かつ既読 weekId が一致 → false', () {
      expect(
        isSuggestionUnread(_suggestion(id: '2026-W24'), '2026-W24'),
        isFalse,
      );
    });

    test('ready かつ既読 weekId が古い（別週）→ true', () {
      expect(
        isSuggestionUnread(_suggestion(id: '2026-W24'), '2026-W23'),
        isTrue,
      );
    });

    test('status: empty は既読 weekId が異なっても false', () {
      expect(
        isSuggestionUnread(
          _suggestion(id: '2026-W24', status: SuggestionStatus.empty),
          '2026-W23',
        ),
        isFalse,
      );
    });
  });
}
