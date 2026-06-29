import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../domain/entities/item.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'item_providers.dart';
import 'repository_providers.dart';

/// アイテム追加の結果。
///
/// 画像アップロードが失敗してもアイテム本体は作成されるため、呼び出し側（UI）が
/// 成功 / 部分失敗を区別してトーストを出し分けられるように型で表現する。
enum AddItemOutcome {
  /// アイテム（＋画像があれば画像も）を追加できた。
  added,

  /// アイテムは追加できたが、画像アップロード / URL 更新に失敗した（本体は残る）。
  addedImageFailed,
}

/// アイテムの追加・更新・削除など書き込み操作を集約するコントローラ。
///
/// Firebase 依存（[itemRepositoryProvider] / [storageRepositoryProvider]）を
/// この層へ閉じ込め、画面（widget）からは本コントローラのメソッドを呼ぶだけにする。
/// UI フィードバック（トースト / ローディング / 画面遷移）は `BuildContext` に
/// 依存するため呼び出し側が担う。失敗時は [AppError] を throw する
/// （[GroupController] / [AuthController] と同方針）。
class ItemController {
  ItemController(this._ref);

  final Ref _ref;

  /// アクティブグループ ID を必須として取得する（未所属は操作不可）。
  String _requireGroupId() {
    final gid = _ref.read(activeGroupIdProvider);
    if (gid == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    return gid;
  }

  String? get _uid => _ref.read(currentUserProvider)?.uid;

  /// リスト末尾に積むための order 値（既存最大 + 1）。
  int _nextOrder() {
    final items = _ref.read(itemsProvider).value ?? const <Item>[];
    return items.fold<int>(
          0,
          (max, i) => (i.order ?? 0) > max ? i.order! : max,
        ) +
        1;
  }

  /// クイック追加（名前のみ）。
  Future<void> quickAdd(String name) async {
    final gid = _requireGroupId();
    final draft = Item(
      id: '',
      name: name,
      category: '',
      note: '',
      imageUrl: '',
      status: ItemStatus.active,
      buyingBy: null,
      addedBy: _uid,
    );
    await _ref.read(itemRepositoryProvider).addItem(gid, draft, _nextOrder());
  }

  /// 詳細追加（2 段階フロー）。
  ///
  /// 1. `addItem`（imageUrl 空）で ID を確定。失敗時は [AppError] を throw する。
  /// 2. 画像があれば Storage アップロード → `updateItemDetails` で imageUrl を更新。
  ///    この段階の失敗はアイテム本体を残したまま [AddItemOutcome.addedImageFailed]
  ///    を返す（本体は削除しない）。
  Future<AddItemOutcome> addItem(Item draft, Uint8List? imageBytes) async {
    final gid = _requireGroupId();
    final items = _ref.read(itemRepositoryProvider);
    final itemId = await items.addItem(
      gid,
      draft.copyWith(addedBy: _uid),
      _nextOrder(),
    );

    if (imageBytes == null) return AddItemOutcome.added;

    try {
      final url = await _ref
          .read(storageRepositoryProvider)
          .uploadItemImage(gid, itemId, imageBytes);
      await items.updateItemDetails(
        gid,
        itemId,
        name: draft.name,
        tagId: draft.tagId,
        note: draft.note,
        imageUrl: url,
      );
      return AddItemOutcome.added;
    } catch (_) {
      // 本体は残す（画像なしで続行）。呼び出し側がエラートーストを出す。
      return AddItemOutcome.addedImageFailed;
    }
  }

  /// アイテム詳細（名前・タグ・メモ・画像）を更新する。
  ///
  /// [imageBytes] が非 null なら先に Storage へアップロードして URL を解決する
  /// （失敗時は [AppError] を throw、`updateItemDetails` は呼ばない）。
  /// 画像が外された（[imageBytes] が null かつ [imageUrl] 空で [originalImageUrl] が
  /// 非空）場合は、更新後に Storage の孤児ファイルを best-effort で削除する。
  Future<void> updateItem(
    String id, {
    required String name,
    String? tagId,
    required String note,
    required String imageUrl,
    Uint8List? imageBytes,
    required String originalImageUrl,
  }) async {
    final gid = _requireGroupId();
    final storage = _ref.read(storageRepositoryProvider);

    var resolvedImageUrl = imageUrl;
    if (imageBytes != null) {
      resolvedImageUrl = await storage.uploadItemImage(gid, id, imageBytes);
    }

    await _ref
        .read(itemRepositoryProvider)
        .updateItemDetails(
          gid,
          id,
          name: name,
          tagId: tagId,
          note: note,
          imageUrl: resolvedImageUrl,
        );

    if (imageBytes == null &&
        resolvedImageUrl.isEmpty &&
        originalImageUrl.isNotEmpty) {
      try {
        await storage.deleteItemImage(gid, id);
      } catch (_) {
        // best-effort: Storage 削除失敗は更新成功を妨げない。
      }
    }
  }

  /// 「買います」宣言者を設定する（null で取り消し）。
  Future<void> setVolunteer(String id, String? uid) async {
    final gid = _requireGroupId();
    await _ref.read(itemRepositoryProvider).setVolunteer(gid, id, uid);
  }

  /// 購入済み / 未購入を切り替える。
  Future<void> setPurchased(String id, bool purchased) async {
    final gid = _requireGroupId();
    await _ref.read(itemRepositoryProvider).setPurchased(gid, id, purchased);
  }

  /// 指定アイテムを削除する。
  Future<void> deleteItem(String id) async {
    final gid = _requireGroupId();
    await _ref.read(itemRepositoryProvider).deleteItem(gid, id);
  }

  /// セクション（タグ）単位で一括削除する。
  ///
  /// [tagId] が null の場合は「タグなし」の未購入アイテムをまとめて削除する。
  Future<void> deleteSection(String? tagId) async {
    final gid = _requireGroupId();
    final repo = _ref.read(itemRepositoryProvider);
    if (tagId != null) {
      await repo.deleteItemsByTag(gid, tagId);
      return;
    }
    final items = _ref.read(itemsProvider).value ?? const <Item>[];
    final noTagIds = items
        .where((i) => i.tagId == null && !i.isPurchased)
        .map((i) => i.id);
    await Future.wait(noTagIds.map((id) => repo.deleteItem(gid, id)));
  }

  /// 複数アイテムのタグを一括変更する（null で解除）。
  Future<void> bulkTagChange(List<String> ids, String? tagId) async {
    final gid = _requireGroupId();
    await _ref.read(itemRepositoryProvider).batchUpdateTag(gid, ids, tagId);
  }
}

/// [ItemController] の DI プロバイダ。
final itemControllerProvider = Provider<ItemController>(
  (ref) => ItemController(ref),
);
