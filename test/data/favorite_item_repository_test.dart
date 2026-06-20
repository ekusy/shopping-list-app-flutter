import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/repositories/firestore_favorite_item_repository.dart';
import 'package:shopping_list_app/domain/entities/favorite_item.dart';

const groupId = 'g1';

FavoriteItem _draft(String name, {String? tagId, int order = 0}) =>
    FavoriteItem(
      id: '',
      name: name,
      tagId: tagId,
      note: '',
      imageUrl: '',
      order: order,
      addedBy: 'u1',
    );

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreFavoriteItemRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreFavoriteItemRepository(db);
  });

  Future<List<FavoriteItem>> firstList() => repo.watchFavorites(groupId).first;

  test('addFavorite はテンプレートを作成し order を設定する', () async {
    final id = await repo.addFavorite(groupId, _draft('牛乳', order: 3), 3);
    final items = await firstList();
    expect(items.length, 1);
    expect(items.first.id, id);
    expect(items.first.name, '牛乳');
    expect(items.first.order, 3);
    expect(items.first.addedBy, 'u1');
  });

  test('watchFavorites は order 昇順でソートする', () async {
    await repo.addFavorite(groupId, _draft('卵', order: 3), 3);
    await repo.addFavorite(groupId, _draft('牛乳', order: 1), 1);
    await repo.addFavorite(groupId, _draft('パン', order: 2), 2);
    final items = await firstList();
    expect(items.map((i) => i.name), ['牛乳', 'パン', '卵']);
  });

  test('addFavorite は tagId を保持する', () async {
    await repo.addFavorite(groupId, _draft('卵', tagId: 't1'), 1);
    final items = await firstList();
    expect(items.first.tagId, 't1');
  });

  test('addFavorite は tagId なしでも動作する', () async {
    await repo.addFavorite(groupId, _draft('牛乳'), 1);
    final items = await firstList();
    expect(items.first.tagId, isNull);
  });

  test('updateFavorite は name を更新する', () async {
    final id = await repo.addFavorite(groupId, _draft('牛乳'), 1);
    await repo.updateFavorite(groupId, id, name: 'スキムミルク');
    final items = await firstList();
    expect(items.first.name, 'スキムミルク');
  });

  test('updateFavorite は tagId=null でタグを解除する', () async {
    final id = await repo.addFavorite(groupId, _draft('卵', tagId: 't1'), 1);
    await repo.updateFavorite(groupId, id, tagId: () => null);
    final items = await firstList();
    expect(items.first.tagId, isNull);
  });

  test('updateFavorite は tagId を新しい値に更新する', () async {
    final id = await repo.addFavorite(groupId, _draft('卵', tagId: 't1'), 1);
    await repo.updateFavorite(groupId, id, tagId: () => 't2');
    final items = await firstList();
    expect(items.first.tagId, 't2');
  });

  test('updateFavorite は note と imageUrl を更新する', () async {
    final id = await repo.addFavorite(groupId, _draft('牛乳'), 1);
    await repo.updateFavorite(
      groupId,
      id,
      note: '低脂肪',
      imageUrl: 'https://example.com/milk.jpg',
    );
    final items = await firstList();
    expect(items.first.note, '低脂肪');
    expect(items.first.imageUrl, 'https://example.com/milk.jpg');
  });

  test('deleteFavorite は単一テンプレートを削除する', () async {
    final id = await repo.addFavorite(groupId, _draft('牛乳'), 1);
    await repo.deleteFavorite(groupId, id);
    expect(await firstList(), isEmpty);
  });

  test('deleteFavorite は対象のみ削除する', () async {
    final id = await repo.addFavorite(groupId, _draft('牛乳', order: 1), 1);
    await repo.addFavorite(groupId, _draft('パン', order: 2), 2);
    await repo.deleteFavorite(groupId, id);
    final items = await firstList();
    expect(items.length, 1);
    expect(items.first.name, 'パン');
  });
}
