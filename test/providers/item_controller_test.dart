import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/errors/app_error.dart';
import 'package:shopping_list_app/domain/entities/auth_user.dart';
import 'package:shopping_list_app/domain/entities/item.dart';
import 'package:shopping_list_app/domain/repositories/item_repository.dart';
import 'package:shopping_list_app/domain/repositories/storage_repository.dart';
import 'package:shopping_list_app/presentation/providers/auth_providers.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/providers/item_controller.dart';
import 'package:shopping_list_app/presentation/providers/item_providers.dart';
import 'package:shopping_list_app/presentation/providers/repository_providers.dart';

// ---------------------------------------------------------------------------
// Fake repositories（呼び出しを記録する）
// ---------------------------------------------------------------------------

class _FakeItemRepo implements ItemRepository {
  final List<({Item draft, int order})> added = [];
  final List<({String itemId, String imageUrl})> updated = [];
  final List<String> deleted = [];
  final List<({List<String> ids, String? tagId})> bulkTag = [];
  String returnId = 'newId';

  @override
  Future<String> addItem(String groupId, Item draft, int order) async {
    added.add((draft: draft, order: order));
    return returnId;
  }

  @override
  Future<void> updateItemDetails(
    String groupId,
    String itemId, {
    required String name,
    String? tagId,
    required String note,
    required String imageUrl,
  }) async {
    updated.add((itemId: itemId, imageUrl: imageUrl));
  }

  @override
  Future<void> deleteItem(String groupId, String itemId) async {
    deleted.add(itemId);
  }

  @override
  Future<void> batchUpdateTag(
    String groupId,
    List<String> itemIds,
    String? tagId,
  ) async {
    bulkTag.add((ids: itemIds, tagId: tagId));
  }

  @override
  Future<void> setVolunteer(String groupId, String itemId, String? uid) async {}

  @override
  Future<void> setPurchased(
    String groupId,
    String itemId,
    bool purchased,
  ) async {}

  @override
  Future<void> deletePurchasedItems(String groupId) async {}

  @override
  Future<void> deleteItemsByTag(String groupId, String tagId) async {}

  @override
  Stream<List<Item>> watchItems(String groupId) => const Stream.empty();
}

class _FakeStorageRepo implements StorageRepository {
  final List<String> uploads = [];
  final List<String> deletes = [];
  bool failUpload = false;
  String returnUrl = 'https://img/new.jpg';

  @override
  Future<String> uploadItemImage(
    String groupId,
    String itemId,
    Uint8List bytes,
  ) async {
    if (failUpload) throw Exception('upload failed');
    uploads.add(itemId);
    return returnUrl;
  }

  @override
  Future<void> deleteItemImage(String groupId, String itemId) async {
    deletes.add(itemId);
  }

  @override
  Future<String> uploadAvatar(String uid, Uint8List bytes) async =>
      'https://avatar';

  @override
  Future<String> uploadFavoriteImage(
    String groupId,
    String favoriteId,
    Uint8List bytes,
  ) async => 'https://fav';

  @override
  Future<void> deleteFavoriteImage(String groupId, String favoriteId) async {}
}

// ---------------------------------------------------------------------------
// ヘルパー
// ---------------------------------------------------------------------------

Item _item({
  String id = 'i',
  int? order,
  String? tagId,
  ItemStatus status = ItemStatus.active,
}) => Item(
  id: id,
  name: 'n',
  category: '',
  note: '',
  imageUrl: '',
  order: order,
  status: status,
  tagId: tagId,
);

/// ストリーム購読の初回イベントが provider に反映されるまで待つ。
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

ProviderContainer _makeContainer({
  required _FakeItemRepo itemRepo,
  required _FakeStorageRepo storageRepo,
  String? groupId = 'g1',
  String? uid = 'u1',
  List<Item> items = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      itemRepositoryProvider.overrideWithValue(itemRepo),
      storageRepositoryProvider.overrideWithValue(storageRepo),
      activeGroupIdProvider.overrideWithValue(groupId),
      currentUserProvider.overrideWithValue(
        uid == null ? null : AuthUser(uid: uid),
      ),
      itemsProvider.overrideWith((ref) => Stream.value(items)),
    ],
  );
  // itemsProvider のライフサイクルを開始して購読を維持する（pure な
  // ProviderContainer テストで `.future` が解決せず disposed になるのを避ける）。
  container.listen(itemsProvider, (_, _) {});
  return container;
}

// ---------------------------------------------------------------------------
// テスト本体
// ---------------------------------------------------------------------------

void main() {
  test('quickAdd は order = 既存最大 + 1 / addedBy = uid で追加する', () async {
    final itemRepo = _FakeItemRepo();
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: _FakeStorageRepo(),
      items: [_item(order: 1), _item(order: 5)],
    );
    addTearDown(container.dispose);
    await _settle();

    await container.read(itemControllerProvider).quickAdd('牛乳');

    expect(itemRepo.added, hasLength(1));
    expect(itemRepo.added.first.order, 6);
    expect(itemRepo.added.first.draft.name, '牛乳');
    expect(itemRepo.added.first.draft.addedBy, 'u1');
  });

  test('addItem（画像あり・成功）は upload → updateItemDetails し added を返す', () async {
    final itemRepo = _FakeItemRepo();
    final storageRepo = _FakeStorageRepo();
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: storageRepo,
    );
    addTearDown(container.dispose);
    await _settle();

    final outcome = await container
        .read(itemControllerProvider)
        .addItem(_item(id: ''), Uint8List.fromList([1, 2, 3]));

    expect(outcome, AddItemOutcome.added);
    expect(itemRepo.added, hasLength(1));
    expect(storageRepo.uploads, ['newId']);
    expect(itemRepo.updated, hasLength(1));
    expect(itemRepo.updated.first.itemId, 'newId');
    expect(itemRepo.updated.first.imageUrl, 'https://img/new.jpg');
  });

  test('addItem（画像あり・アップロード失敗）は本体を残し addedImageFailed を返す', () async {
    final itemRepo = _FakeItemRepo();
    final storageRepo = _FakeStorageRepo()..failUpload = true;
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: storageRepo,
    );
    addTearDown(container.dispose);
    await _settle();

    final outcome = await container
        .read(itemControllerProvider)
        .addItem(_item(id: ''), Uint8List.fromList([1]));

    expect(outcome, AddItemOutcome.addedImageFailed);
    expect(itemRepo.added, hasLength(1)); // 本体は作成済み
    expect(itemRepo.updated, isEmpty); // 詳細更新はスキップ
  });

  test('addItem（画像なし）は upload せず added を返す', () async {
    final itemRepo = _FakeItemRepo();
    final storageRepo = _FakeStorageRepo();
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: storageRepo,
    );
    addTearDown(container.dispose);
    await _settle();

    final outcome = await container
        .read(itemControllerProvider)
        .addItem(_item(id: ''), null);

    expect(outcome, AddItemOutcome.added);
    expect(storageRepo.uploads, isEmpty);
    expect(itemRepo.updated, isEmpty);
  });

  test('updateItem で画像が外されたら孤児ファイルを削除する', () async {
    final itemRepo = _FakeItemRepo();
    final storageRepo = _FakeStorageRepo();
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: storageRepo,
    );
    addTearDown(container.dispose);

    await container
        .read(itemControllerProvider)
        .updateItem(
          'id1',
          name: 'x',
          tagId: null,
          note: '',
          imageUrl: '',
          imageBytes: null,
          originalImageUrl: 'https://old.jpg',
        );

    expect(itemRepo.updated.single.imageUrl, '');
    expect(storageRepo.deletes, ['id1']);
  });

  test('updateItem で新規画像があれば upload した URL で更新し削除しない', () async {
    final itemRepo = _FakeItemRepo();
    final storageRepo = _FakeStorageRepo();
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: storageRepo,
    );
    addTearDown(container.dispose);

    await container
        .read(itemControllerProvider)
        .updateItem(
          'id1',
          name: 'x',
          tagId: 't',
          note: 'm',
          imageUrl: '',
          imageBytes: Uint8List.fromList([1]),
          originalImageUrl: '',
        );

    expect(storageRepo.uploads, ['id1']);
    expect(itemRepo.updated.single.imageUrl, 'https://img/new.jpg');
    expect(storageRepo.deletes, isEmpty);
  });

  test('deleteSection(null) はタグなしの未購入アイテムのみ削除する', () async {
    final itemRepo = _FakeItemRepo();
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: _FakeStorageRepo(),
      items: [
        _item(id: 'a', tagId: null),
        _item(id: 'b', tagId: 't1'),
        _item(id: 'c', tagId: null, status: ItemStatus.purchased),
      ],
    );
    addTearDown(container.dispose);
    await _settle();

    await container.read(itemControllerProvider).deleteSection(null);

    expect(itemRepo.deleted, ['a']);
  });

  test('bulkTagChange は batchUpdateTag へ委譲する', () async {
    final itemRepo = _FakeItemRepo();
    final container = _makeContainer(
      itemRepo: itemRepo,
      storageRepo: _FakeStorageRepo(),
    );
    addTearDown(container.dispose);

    await container.read(itemControllerProvider).bulkTagChange([
      'a',
      'b',
    ], 't1');

    expect(itemRepo.bulkTag.single.ids, ['a', 'b']);
    expect(itemRepo.bulkTag.single.tagId, 't1');
  });

  test('グループ未所属時は AppError を throw する', () async {
    final container = _makeContainer(
      itemRepo: _FakeItemRepo(),
      storageRepo: _FakeStorageRepo(),
      groupId: null,
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(itemControllerProvider).quickAdd('x'),
      throwsA(isA<AppError>()),
    );
  });
}
