import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/suggestion.dart';
import 'package:shopping_list_app/presentation/providers/suggestion_providers.dart';
import 'package:shopping_list_app/presentation/screens/suggestions/suggestions_screen.dart';

import '../helpers/test_localization.dart';

/// 提案画面を、テスト用ローカライズ + Riverpod override で描画する。
///
/// `.tr()` はウィジェットテストではキーをそのまま返す（翻訳値は解決されない）ため、
/// 本テストは既存の widget テスト（`item_card_test.dart`）と同様に**構造・データ**
/// （ウィジェット型 / アイコン / 商品名）で検証し、翻訳済み文言には依存しない。
Future<void> _pumpScreen(
  WidgetTester tester, {
  required Suggestion? suggestion,
}) async {
  await pumpLocalized(
    tester,
    ProviderScope(
      overrides: [
        latestSuggestionProvider.overrideWith(
          (ref) => Stream.value(suggestion),
        ),
      ],
      child: const SuggestionsScreen(),
    ),
    locale: const Locale('ja'),
  );
}

Suggestion _suggestion({
  SuggestionStatus status = SuggestionStatus.ready,
  List<ForgottenItem> forgottenItems = const [],
  List<RecommendedItem> recommendedItems = const [],
}) => Suggestion(
  id: '2026-W24',
  generatedAt: DateTime(2026, 6, 14, 8, 0),
  status: status,
  forgottenItems: forgottenItems,
  recommendedItems: recommendedItems,
);

void main() {
  setUpAll(() async {
    await setUpTestLocalization();
  });

  testWidgets('forgotten / recommended のアイテム名・理由をカードで描画する', (tester) async {
    final suggestion = _suggestion(
      forgottenItems: const [
        ForgottenItem(
          name: '牛乳',
          reason: '先週買い忘れた',
          confidence: SuggestionConfidence.high,
        ),
      ],
      recommendedItems: const [RecommendedItem(name: '卵', reason: '毎週購入している')],
    );

    await _pumpScreen(tester, suggestion: suggestion);

    // データ（商品名・理由）はロケールに依存せず描画される。
    expect(find.text('牛乳'), findsOneWidget);
    expect(find.text('先週買い忘れた'), findsOneWidget);
    expect(find.text('卵'), findsOneWidget);
    expect(find.text('毎週購入している'), findsOneWidget);
    // forgotten 1 + recommended 1 = 2 カード。
    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('提案がない（null）場合は空状態（カードなし）を表示する', (tester) async {
    await _pumpScreen(tester, suggestion: null);

    expect(find.byType(Card), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets('status: empty の場合も空状態を表示する', (tester) async {
    await _pumpScreen(
      tester,
      suggestion: _suggestion(status: SuggestionStatus.empty),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets('各提案アイテムに「リストに追加」ボタンが1つずつ表示される', (tester) async {
    final suggestion = _suggestion(
      forgottenItems: const [
        ForgottenItem(
          name: '牛乳',
          reason: '理由',
          confidence: SuggestionConfidence.high,
        ),
        ForgottenItem(
          name: 'パン',
          reason: '理由',
          confidence: SuggestionConfidence.medium,
        ),
      ],
      recommendedItems: const [RecommendedItem(name: '卵', reason: '理由')],
    );

    await _pumpScreen(tester, suggestion: suggestion);

    // 3 アイテム → 3 カード → 各カードに 1 つの追加ボタン（OutlinedButton）。
    expect(find.byType(Card), findsNWidgets(3));
    expect(find.byType(OutlinedButton), findsNWidgets(3));
  });

  testWidgets('コンテンツありの場合はフッター（Divider）を表示する', (tester) async {
    final suggestion = _suggestion(
      forgottenItems: const [
        ForgottenItem(
          name: '牛乳',
          reason: '理由',
          confidence: SuggestionConfidence.high,
        ),
      ],
    );

    await _pumpScreen(tester, suggestion: suggestion);

    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('confidence に応じたバッジ（medium: ?, low: ??）を表示する', (tester) async {
    final suggestion = _suggestion(
      forgottenItems: const [
        ForgottenItem(
          name: '牛乳',
          reason: '理由',
          confidence: SuggestionConfidence.medium,
        ),
        ForgottenItem(
          name: 'パン',
          reason: '理由',
          confidence: SuggestionConfidence.low,
        ),
      ],
    );

    await _pumpScreen(tester, suggestion: suggestion);

    expect(find.text('?'), findsOneWidget);
    expect(find.text('??'), findsOneWidget);
  });
}
