import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/favorite_item.dart';

FavoriteItem _item({
  String id = 'f1',
  String name = '牛乳',
  String? tagId,
  String note = '',
  String imageUrl = '',
  int order = 0,
  String addedBy = 'u1',
  DateTime? createdAt,
}) {
  return FavoriteItem(
    id: id,
    name: name,
    tagId: tagId,
    note: note,
    imageUrl: imageUrl,
    order: order,
    addedBy: addedBy,
    createdAt: createdAt,
  );
}

void main() {
  group('FavoriteItem フィールド保持', () {
    test('全フィールドが正しく保持される', () {
      final now = DateTime(2026, 1, 1);
      final item = _item(
        id: 'f1',
        name: '卵',
        tagId: 't1',
        note: '6個入り',
        imageUrl: 'https://example.com/egg.jpg',
        order: 3,
        addedBy: 'u2',
        createdAt: now,
      );
      expect(item.id, 'f1');
      expect(item.name, '卵');
      expect(item.tagId, 't1');
      expect(item.note, '6個入り');
      expect(item.imageUrl, 'https://example.com/egg.jpg');
      expect(item.order, 3);
      expect(item.addedBy, 'u2');
      expect(item.createdAt, now);
    });

    test('tagId はデフォルトで null', () {
      expect(_item().tagId, isNull);
    });

    test('createdAt はデフォルトで null', () {
      expect(_item().createdAt, isNull);
    });
  });

  group('FavoriteItem.copyWith', () {
    test('name を上書きできる', () {
      final updated = _item(name: '牛乳').copyWith(name: 'パン');
      expect(updated.name, 'パン');
    });

    test('指定しないフィールドは元の値を保持する', () {
      final original = _item(name: '牛乳', order: 2, addedBy: 'u1');
      final updated = original.copyWith(name: 'パン');
      expect(updated.order, 2);
      expect(updated.addedBy, 'u1');
    });

    test('tagId を null で解除できる', () {
      final original = _item(tagId: 't1');
      final updated = original.copyWith(tagId: () => null);
      expect(updated.tagId, isNull);
    });

    test('tagId を新しい値に更新できる', () {
      final original = _item(tagId: 't1');
      final updated = original.copyWith(tagId: () => 't2');
      expect(updated.tagId, 't2');
    });

    test('tagId を指定しなければ元の値を保持する', () {
      final original = _item(tagId: 't1');
      final updated = original.copyWith(name: 'パン');
      expect(updated.tagId, 't1');
    });

    test('order を更新できる', () {
      final updated = _item(order: 1).copyWith(order: 5);
      expect(updated.order, 5);
    });
  });

  group('FavoriteItem == / hashCode', () {
    test('同一フィールドは等値', () {
      final a = _item();
      final b = _item();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('name が異なれば不等値', () {
      expect(_item(name: '牛乳'), isNot(equals(_item(name: 'パン'))));
    });

    test('order が異なれば不等値', () {
      expect(_item(order: 1), isNot(equals(_item(order: 2))));
    });
  });
}
