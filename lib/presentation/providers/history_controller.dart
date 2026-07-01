import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/purchase_history_entry.dart';
import 'group_providers.dart';
import 'repository_providers.dart';

/// 1 ページあたりの取得件数。
const _pageSize = 30;

/// 購入履歴タイムラインの状態（ページング）。
class HistoryState {
  const HistoryState({
    this.entries = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error = false,
  });

  /// これまでに読み込んだ購入イベント（occurredAt 降順）。
  final List<PurchaseHistoryEntry> entries;

  /// 初回ロード中か。
  final bool loading;

  /// 追加ページのロード中か。
  final bool loadingMore;

  /// さらに過去のページがあるか。
  final bool hasMore;

  /// 初回ロードに失敗したか。
  final bool error;

  HistoryState copyWith({
    List<PurchaseHistoryEntry>? entries,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? error,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

/// 購入履歴タイムラインのコントローラ（`get` ベースのページング）。
///
/// アクティブグループを監視し、グループ確定時に先頭ページを読み込む。グループが
/// 変わると再構築されて読み直す。リアルタイム購読はしない（履歴は Functions が
/// 書き込む追記型で即時性が不要なため）。
class HistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    final gid = ref.watch(activeGroupIdProvider);
    if (gid == null) {
      return const HistoryState(loading: false, hasMore: false);
    }
    _loadFirst(gid);
    return const HistoryState();
  }

  Future<void> _loadFirst(String gid) async {
    try {
      final page = await ref
          .read(historyRepositoryProvider)
          .fetchPurchases(gid, limit: _pageSize);
      state = HistoryState(
        entries: page,
        loading: false,
        hasMore: page.length == _pageSize,
      );
    } catch (_) {
      state = const HistoryState(loading: false, hasMore: false, error: true);
    }
  }

  /// 次の（より古い）ページを読み込んで末尾に追加する。
  Future<void> loadMore() async {
    final gid = ref.read(activeGroupIdProvider);
    if (gid == null) return;
    if (state.loading ||
        state.loadingMore ||
        !state.hasMore ||
        state.entries.isEmpty) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    try {
      final page = await ref
          .read(historyRepositoryProvider)
          .fetchPurchases(
            gid,
            limit: _pageSize,
            before: state.entries.last.occurredAt,
          );
      state = state.copyWith(
        entries: [...state.entries, ...page],
        loadingMore: false,
        hasMore: page.length == _pageSize,
      );
    } catch (_) {
      // 追加ロード失敗は静かに止める（スクロールで再試行できる）。
      state = state.copyWith(loadingMore: false);
    }
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);
