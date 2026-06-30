import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/purchase_history_entry.dart';
import 'package:shopping_list_app/domain/repositories/history_repository.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/providers/history_controller.dart';
import 'package:shopping_list_app/presentation/providers/repository_providers.dart';

/// 呼び出しごとに `pages` を順に返す fake。`before` 引数を記録する。
class _FakeHistoryRepo implements HistoryRepository {
  _FakeHistoryRepo(this.pages);
  final List<List<PurchaseHistoryEntry>> pages;
  int callCount = 0;
  final List<DateTime?> beforeArgs = [];

  @override
  Future<List<PurchaseHistoryEntry>> fetchPurchases(
    String groupId, {
    required int limit,
    DateTime? before,
  }) async {
    beforeArgs.add(before);
    final page = callCount < pages.length
        ? pages[callCount]
        : <PurchaseHistoryEntry>[];
    callCount++;
    return page;
  }
}

PurchaseHistoryEntry _entry(int i) => PurchaseHistoryEntry(
  id: 'e$i',
  itemId: 'item$i',
  name: 'name$i',
  occurredAt: DateTime(2026, 6, 30).subtract(Duration(hours: i)),
);

List<PurchaseHistoryEntry> _entries(int n) => List.generate(n, _entry);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

ProviderContainer _makeContainer({
  required HistoryRepository repo,
  String? groupId = 'g1',
}) {
  final container = ProviderContainer(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
      activeGroupIdProvider.overrideWithValue(groupId),
    ],
  );
  container.listen(historyControllerProvider, (_, _) {});
  return container;
}

void main() {
  test('初回ロードで先頭ページを読み、満杯なら hasMore=true', () async {
    final repo = _FakeHistoryRepo([_entries(30)]);
    final container = _makeContainer(repo: repo);
    addTearDown(container.dispose);
    await _settle();

    final state = container.read(historyControllerProvider);
    expect(state.loading, isFalse);
    expect(state.entries, hasLength(30));
    expect(state.hasMore, isTrue);
    expect(repo.beforeArgs.first, isNull); // 先頭ページはカーソルなし
  });

  test('先頭ページが limit 未満なら hasMore=false', () async {
    final container = _makeContainer(repo: _FakeHistoryRepo([_entries(10)]));
    addTearDown(container.dispose);
    await _settle();

    final state = container.read(historyControllerProvider);
    expect(state.entries, hasLength(10));
    expect(state.hasMore, isFalse);
  });

  test('loadMore は末尾の occurredAt をカーソルに次ページを追加する', () async {
    final repo = _FakeHistoryRepo([_entries(30), _entries(5)]);
    final container = _makeContainer(repo: repo);
    addTearDown(container.dispose);
    await _settle();

    final firstLast = container.read(historyControllerProvider).entries.last;

    await container.read(historyControllerProvider.notifier).loadMore();
    await _settle();

    final state = container.read(historyControllerProvider);
    expect(state.entries, hasLength(35));
    expect(state.hasMore, isFalse); // 2 ページ目は 5 件 < 30
    expect(state.loadingMore, isFalse);
    expect(repo.beforeArgs.last, firstLast.occurredAt); // カーソル
  });

  test('hasMore=false のとき loadMore は何もしない', () async {
    final repo = _FakeHistoryRepo([_entries(10)]);
    final container = _makeContainer(repo: repo);
    addTearDown(container.dispose);
    await _settle();

    await container.read(historyControllerProvider.notifier).loadMore();
    await _settle();

    expect(repo.callCount, 1); // 追加取得は走らない
  });

  test('グループ未所属時はロードせず空状態', () async {
    final repo = _FakeHistoryRepo([_entries(30)]);
    final container = _makeContainer(repo: repo, groupId: null);
    addTearDown(container.dispose);
    await _settle();

    final state = container.read(historyControllerProvider);
    expect(state.loading, isFalse);
    expect(state.entries, isEmpty);
    expect(state.hasMore, isFalse);
    expect(repo.callCount, 0);
  });
}
