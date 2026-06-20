import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/plan_limits.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/name_key.dart';
import '../../domain/entities/favorite_item.dart';
import '../../domain/entities/item.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'item_providers.dart';
import 'repository_providers.dart';

/// アクティブグループ配下のよく買う物テンプレートをリアルタイム購読する。
///
/// グループ未所属時は空配列を返す。order 昇順。
final favoritesProvider = StreamProvider<List<FavoriteItem>>((ref) {
  final gid = ref.watch(activeGroupIdProvider);
  if (gid == null) return Stream.value(const <FavoriteItem>[]);
  final repo = ref.watch(favoriteItemRepositoryProvider);
  return repo.watchFavorites(gid);
});

// ---------------------------------------------------------------------------
// 純粋関数（top-level、ユニットテスト対象）
// ---------------------------------------------------------------------------

/// [selected] の中から、未購入のアクティブアイテム名と重複しないものを返す。
///
/// 重複判定は [normalizeName] で正規化した名前の一致で行う。
List<FavoriteItem> filterNewFavorites(
  List<FavoriteItem> selected,
  List<Item> activeItems,
) {
  final activeNames = activeItems
      .where((i) => !i.isPurchased)
      .map((i) => normalizeName(i.name))
      .toSet();
  return selected
      .where((f) => !activeNames.contains(normalizeName(f.name)))
      .toList();
}

// ---------------------------------------------------------------------------
// FavoriteController
// ---------------------------------------------------------------------------

/// よく買う物テンプレートの CRUD と一括追加を担うコントローラ。
class FavoriteController {
  FavoriteController(this._ref);

  final Ref _ref;

  String? get _groupId => _ref.read(activeGroupProvider)?.id;
  String? get _uid => _ref.read(currentUserProvider)?.uid;

  /// 現在のよく買う物テンプレート一覧を取得する（上限チェックに使用）。
  Future<List<FavoriteItem>> _currentFavorites(String groupId) {
    return _ref
        .read(favoriteItemRepositoryProvider)
        .watchFavorites(groupId)
        .first;
  }

  /// 次の order 値（既存最大 + 1）を計算する。
  int _nextOrder(List<FavoriteItem> favorites) {
    return favorites.fold<int>(0, (max, f) => f.order > max ? f.order : max) +
        1;
  }

  /// よく買う物テンプレートを追加する。
  ///
  /// プラン上限に達している場合は [AppErrorCode.dataFavoriteLimitExceeded] を throw する。
  ///
  /// 2 段保存フロー（アイテム追加と同方針）:
  ///   1. `addFavorite`（imageUrl 空 or 既存コピー値）→ ドキュメント ID を確定
  ///   2. [imageBytes] が非 null なら Storage アップロード → `updateFavorite` で
  ///      imageUrl を更新（best-effort: 画像失敗でも本体は残す）
  Future<void> addFavorite({
    required String name,
    String? tagId,
    String note = '',
    String imageUrl = '',
    Uint8List? imageBytes,
  }) async {
    final group = _ref.read(activeGroupProvider);
    if (group == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    final favorites = await _currentFavorites(group.id);
    final limit = PlanLimits.favoriteLimitFor(group.plan);
    if (limit != null && favorites.length >= limit) {
      throw AppError(
        AppErrorCode.dataFavoriteLimitExceeded,
        'Favorite limit reached ($limit)',
      );
    }
    final order = _nextOrder(favorites);
    final draft = FavoriteItem(
      id: '',
      name: name.trim(),
      tagId: tagId,
      note: note,
      // 新規画像がある場合は空で保存し、アップロード後に URL を更新する
      imageUrl: imageBytes != null ? '' : imageUrl,
      order: order,
      addedBy: _uid ?? '',
    );
    final id = await _ref
        .read(favoriteItemRepositoryProvider)
        .addFavorite(group.id, draft, order);

    // ステップ 2: Storage アップロード + imageUrl 更新（best-effort）
    if (imageBytes != null) {
      try {
        final url = await _ref
            .read(storageRepositoryProvider)
            .uploadFavoriteImage(group.id, id, imageBytes);
        await _ref
            .read(favoriteItemRepositoryProvider)
            .updateFavorite(group.id, id, imageUrl: url);
      } catch (_) {
        // 画像なしで本体は残す（best-effort）。
      }
    }
  }

  /// よく買う物テンプレートを更新する。
  ///
  /// 画像の扱い（アイテム編集と同方針）:
  ///   - [imageBytes] が非 null: Storage アップロード後にその URL で更新する。
  ///   - [imageBytes] が null かつ [imageUrl] が空かつ [previousImageUrl] が非空:
  ///     画像が外されたとみなし、更新後に `deleteFavoriteImage` を best-effort 実行する。
  ///   - それ以外: [imageUrl] をそのまま反映する。
  Future<void> updateFavorite(
    String id, {
    String? name,
    String? Function()? tagId,
    String? note,
    String? imageUrl,
    Uint8List? imageBytes,
    String previousImageUrl = '',
  }) async {
    final groupId = _groupId;
    if (groupId == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }

    // 新規画像が選択された場合は Storage アップロードを先に行い URL を取得する
    String? resolvedImageUrl = imageUrl;
    if (imageBytes != null) {
      resolvedImageUrl = await _ref
          .read(storageRepositoryProvider)
          .uploadFavoriteImage(groupId, id, imageBytes);
    }

    await _ref
        .read(favoriteItemRepositoryProvider)
        .updateFavorite(
          groupId,
          id,
          name: name,
          tagId: tagId,
          note: note,
          imageUrl: resolvedImageUrl,
        );

    // 画像が外された場合（新規バイト列なし・URL 空・元に画像あり）、
    // Storage の孤児ファイルを best-effort で削除する。
    if (imageBytes == null &&
        (resolvedImageUrl == null || resolvedImageUrl.isEmpty) &&
        previousImageUrl.isNotEmpty) {
      try {
        await _ref
            .read(storageRepositoryProvider)
            .deleteFavoriteImage(groupId, id);
      } catch (_) {
        // best-effort: Storage 削除失敗は update 成功を妨げない
      }
    }
  }

  /// よく買う物テンプレートを削除する。
  ///
  /// favorites には Functions トリガが無いため、ドキュメント削除後に
  /// `deleteFavoriteImage` を best-effort で呼んで孤児画像を防ぐ。
  Future<void> deleteFavorite(String id) async {
    final groupId = _groupId;
    if (groupId == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    await _ref.read(favoriteItemRepositoryProvider).deleteFavorite(groupId, id);
    try {
      await _ref
          .read(storageRepositoryProvider)
          .deleteFavoriteImage(groupId, id);
    } catch (_) {
      // best-effort: Storage 削除失敗はドキュメント削除を妨げない
    }
  }

  /// アイテムをよく買う物テンプレートに昇格する。
  ///
  /// name / tagId / note / imageUrl をコピーして addFavorite を呼ぶ。
  /// プラン上限に達している場合は [AppErrorCode.dataFavoriteLimitExceeded] を throw する。
  Future<void> addFromItem(Item item) async {
    await addFavorite(
      name: item.name,
      tagId: item.tagId,
      note: item.note,
      imageUrl: item.imageUrl,
    );
  }

  /// 選択したよく買う物テンプレートを買い物リストに一括追加する。
  ///
  /// 未購入アクティブアイテムと名前が重複するものはスキップする。
  /// 非重複のものをリスト先頭に挿入する（現在の最小 order より小さい order を割り当てる）。
  ///
  /// 各追加は独立に行い、1 件の失敗で残りを止めない（best-effort）。返り値の `added` は
  /// **実際に追加できた件数**、`skipped` は重複でスキップした件数を表す。
  ///
  /// @returns `({int added, int skipped})` 追加/スキップ件数のレコード
  Future<({int added, int skipped})> addFavoritesToList(
    List<FavoriteItem> selected,
  ) async {
    final groupId = _groupId;
    if (groupId == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    // 重複判定の突合元はアクティブアイテムの確定値を使う。未解決スナップショット
    // （`.value` が null）だと重複品を新規と誤判定して二重追加し得るため、
    // `.future` で初回値の確定を待つ。
    final activeItems = await _ref.read(itemsProvider.future);
    final toAdd = filterNewFavorites(selected, activeItems);
    final skipped = selected.length - toAdd.length;

    if (toAdd.isEmpty) return (added: 0, skipped: skipped);

    // 現在の最小 order を基準に先頭挿入用の order を計算する。
    // selected の順番を維持しつつ先頭に並べるため、minOrder - toAdd.length から割り当てる。
    final currentOrders = activeItems.map((i) => i.order ?? 0).toList();
    final minOrder = currentOrders.isEmpty
        ? 0
        : currentOrders.reduce((a, b) => a < b ? a : b);
    final startOrder = minOrder - toAdd.length;

    final itemRepo = _ref.read(itemRepositoryProvider);
    // 1 件の失敗で残りの追加を止めないよう各追加を独立に行い、成功数を数える。
    var added = 0;
    for (var i = 0; i < toAdd.length; i++) {
      final fav = toAdd[i];
      final draft = Item(
        id: '',
        name: fav.name,
        category: '',
        note: fav.note,
        imageUrl: fav.imageUrl,
        status: ItemStatus.active,
        buyingBy: null,
        tagId: fav.tagId,
        addedBy: _uid,
      );
      try {
        await itemRepo.addItem(groupId, draft, startOrder + i);
        added++;
      } catch (_) {
        // best-effort: 失敗分は added に数えず、UI のトーストが実際の成功件数を表示する。
      }
    }

    return (added: added, skipped: skipped);
  }
}

/// [FavoriteController] の DI プロバイダ。
final favoriteControllerProvider = Provider<FavoriteController>(
  (ref) => FavoriteController(ref),
);
