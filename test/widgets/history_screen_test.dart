import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/purchase_history_entry.dart';
import 'package:shopping_list_app/presentation/providers/group_members_provider.dart';
import 'package:shopping_list_app/presentation/providers/history_controller.dart';
import 'package:shopping_list_app/presentation/screens/history/history_screen.dart';

import '../helpers/test_localization.dart';

/// 固定 state を返すテスト用 HistoryController。
class _FakeHistoryController extends HistoryController {
  _FakeHistoryController(this._state);
  final HistoryState _state;

  @override
  HistoryState build() => _state;

  @override
  Future<void> loadMore() async {}
}

PurchaseHistoryEntry _entry({
  required String id,
  required String name,
  required DateTime occurredAt,
  String? purchasedBy,
}) => PurchaseHistoryEntry(
  id: id,
  itemId: 'item_$id',
  name: name,
  purchasedBy: purchasedBy,
  occurredAt: occurredAt,
);

Future<void> _pump(
  WidgetTester tester, {
  required HistoryState state,
  Map<String, String> memberNames = const {},
}) async {
  await pumpLocalized(
    tester,
    const HistoryScreen(),
    locale: const Locale('ja'),
    wrapper: (app) => ProviderScope(
      overrides: [
        historyControllerProvider.overrideWith(
          () => _FakeHistoryController(state),
        ),
        groupMemberNamesProvider.overrideWith(
          (ref) => Stream.value(memberNames),
        ),
      ],
      child: app,
    ),
  );
}

void main() {
  setUpAll(() async {
    await setUpTestLocalization();
  });

  testWidgets('履歴が空のとき空状態を表示する', (tester) async {
    await _pump(
      tester,
      state: const HistoryState(entries: [], loading: false, hasMore: false),
    );

    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });

  testWidgets('購入履歴を週ごとにグルーピングして再追加ボタン付きで表示する', (tester) async {
    final entries = [
      _entry(
        id: '1',
        name: '牛乳',
        occurredAt: DateTime(2026, 6, 29, 14, 0),
        purchasedBy: 'u1',
      ),
      _entry(id: '2', name: '卵', occurredAt: DateTime(2026, 6, 20, 9, 0)),
    ];

    await _pump(
      tester,
      state: HistoryState(entries: entries, loading: false, hasMore: false),
      memberNames: const {'u1': 'たろう'},
    );

    expect(find.byKey(const Key('history_list')), findsOneWidget);
    // 商品名が描画される
    expect(find.text('牛乳'), findsOneWidget);
    expect(find.text('卵'), findsOneWidget);
    // 各行に再追加ボタン
    expect(find.byKey(const Key('history_readd_1')), findsOneWidget);
    expect(find.byKey(const Key('history_readd_2')), findsOneWidget);
    // 別々の週なので週見出しが 2 つ
    expect(find.textContaining('history.week_of'), findsNWidgets(2));
    // TTL 注記
    expect(find.text('history.ttl_note'), findsOneWidget);
    // 購入者の表示（u1 → たろう）
    expect(find.textContaining('history.purchased_by'), findsOneWidget);
  });
}
