import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/repositories/firestore_item_repository.dart';
import 'package:shopping_list_app/data/repositories/firestore_tag_repository.dart';
import 'package:shopping_list_app/domain/entities/item.dart';

const groupId = 'g1';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTagRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreTagRepository(db);
  });

  test('addTag はタグを作成する', () async {
    final tag = await repo.addTag(groupId, 'urgent', 1);
    expect(tag.name, 'urgent');
    expect(tag.order, 1);
    expect(await repo.getTagsCount(groupId), 1);
  });

  test('watchTags は order 昇順でソートする', () async {
    await repo.addTag(groupId, 'b', 2);
    await repo.addTag(groupId, 'a', 1);
    await repo.addTag(groupId, 'c', 3);
    final tags = await repo.watchTags(groupId).first;
    expect(tags.map((t) => t.name), ['a', 'b', 'c']);
  });

  test('updateTagName は名前を更新する', () async {
    final tag = await repo.addTag(groupId, 'old', 1);
    await repo.updateTagName(groupId, tag.id, 'new');
    final tags = await repo.watchTags(groupId).first;
    expect(tags.single.name, 'new');
  });

  test('deleteTagAndClearItems はタグを削除し参照アイテムの tagId をクリアする', () async {
    final itemRepo = FirestoreItemRepository(db);
    final tag = await repo.addTag(groupId, 't', 1);
    final itemId = await itemRepo.addItem(
      groupId,
      Item(
        id: '',
        name: 'x',
        category: '',
        note: '',
        imageUrl: '',
        status: ItemStatus.active,
        tagId: tag.id,
      ),
      1,
    );

    await repo.deleteTagAndClearItems(groupId, tag.id);

    expect(await repo.getTagsCount(groupId), 0);
    final items = await itemRepo.watchItems(groupId).first;
    expect(items.firstWhere((i) => i.id == itemId).tagId, isNull);
  });
}
