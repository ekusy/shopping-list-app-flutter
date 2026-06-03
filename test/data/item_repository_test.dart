import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/repositories/firestore_item_repository.dart';
import 'package:shopping_list_app/domain/entities/item.dart';

const groupId = 'g1';

Item _draft(String name, {String? tagId}) => Item(
  id: '',
  name: name,
  category: '',
  note: '',
  imageUrl: '',
  status: ItemStatus.active,
  buyingBy: null,
  tagId: tagId,
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreItemRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreItemRepository(db);
  });

  Future<Item> firstItem() async =>
      (await repo.watchItems(groupId).first).first;

  test('addItem はアイテムを作成し order を設定する', () async {
    final id = await repo.addItem(groupId, _draft('milk'), 3);
    final item = await firstItem();
    expect(item.id, id);
    expect(item.name, 'milk');
    expect(item.order, 3);
    expect(item.status, ItemStatus.active);
  });

  test('setVolunteer は buyingBy を設定 / null 解除する', () async {
    final id = await repo.addItem(groupId, _draft('milk'), 1);
    await repo.setVolunteer(groupId, id, 'u1');
    expect((await firstItem()).buyingBy, 'u1');
    await repo.setVolunteer(groupId, id, null);
    expect((await firstItem()).buyingBy, isNull);
  });

  test('setPurchased は status を切り替える', () async {
    final id = await repo.addItem(groupId, _draft('milk'), 1);
    await repo.setPurchased(groupId, id, true);
    expect((await firstItem()).status, ItemStatus.purchased);
    await repo.setPurchased(groupId, id, false);
    expect((await firstItem()).status, ItemStatus.active);
  });

  test('updateItemDetails は tagId=null でフィールドを削除する', () async {
    final id = await repo.addItem(groupId, _draft('milk', tagId: 't1'), 1);
    await repo.updateItemDetails(
      groupId,
      id,
      name: 'bread',
      tagId: null,
      note: 'n',
      imageUrl: '',
    );
    final item = await firstItem();
    expect(item.name, 'bread');
    expect(item.note, 'n');
    expect(item.tagId, isNull);
  });

  test('deletePurchasedItems は購入済みのみ削除する', () async {
    final a = await repo.addItem(groupId, _draft('a'), 1);
    await repo.addItem(groupId, _draft('b'), 2);
    await repo.setPurchased(groupId, a, true);
    await repo.deletePurchasedItems(groupId);
    final items = await repo.watchItems(groupId).first;
    expect(items.map((i) => i.name), ['b']);
  });

  test('deleteItemsByTag は対象タグのアイテムのみ削除する', () async {
    await repo.addItem(groupId, _draft('a', tagId: 't1'), 1);
    await repo.addItem(groupId, _draft('b', tagId: 't2'), 2);
    await repo.deleteItemsByTag(groupId, 't1');
    final items = await repo.watchItems(groupId).first;
    expect(items.map((i) => i.name), ['b']);
  });

  test('batchUpdateTag は複数アイテムのタグを更新する', () async {
    final a = await repo.addItem(groupId, _draft('a'), 1);
    final b = await repo.addItem(groupId, _draft('b'), 2);
    await repo.batchUpdateTag(groupId, [a, b], 't9');
    final items = await repo.watchItems(groupId).first;
    expect(items.every((i) => i.tagId == 't9'), isTrue);
  });

  test('watchItems は order 昇順でソートする', () async {
    await repo.addItem(groupId, _draft('third'), 3);
    await repo.addItem(groupId, _draft('first'), 1);
    await repo.addItem(groupId, _draft('second'), 2);
    final items = await repo.watchItems(groupId).first;
    expect(items.map((i) => i.name), ['first', 'second', 'third']);
  });

  test('deleteItem は単一アイテムを削除する', () async {
    final id = await repo.addItem(groupId, _draft('a'), 1);
    await repo.deleteItem(groupId, id);
    expect(await repo.watchItems(groupId).first, isEmpty);
  });
}
