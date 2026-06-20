import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/favorite_item.dart';
import 'package:shopping_list_app/domain/entities/item.dart';
import 'package:shopping_list_app/presentation/providers/favorite_providers.dart';

// ---------------------------------------------------------------------------
// テスト用ファクトリ
// ---------------------------------------------------------------------------

FavoriteItem _fav({
  required String id,
  required String name,
  String? tagId,
  String note = '',
  String imageUrl = '',
  int order = 0,
}) => FavoriteItem(
  id: id,
  name: name,
  tagId: tagId,
  note: note,
  imageUrl: imageUrl,
  order: order,
  addedBy: 'user1',
);

Item _item({
  required String id,
  required String name,
  ItemStatus status = ItemStatus.active,
}) => Item(
  id: id,
  name: name,
  category: '',
  note: '',
  imageUrl: '',
  status: status,
);

// ---------------------------------------------------------------------------
// filterNewFavorites の純粋ユニットテスト
// ---------------------------------------------------------------------------

void main() {
  group('filterNewFavorites', () {
    test('アクティブアイテムと名前が重複するものを除外する', () {
      final selected = [_fav(id: '1', name: '牛乳'), _fav(id: '2', name: '卵')];
      final activeItems = [_item(id: 'a', name: '牛乳')];

      final result = filterNewFavorites(selected, activeItems);

      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('アクティブアイテムが空の場合はすべて返す', () {
      final selected = [_fav(id: '1', name: '牛乳'), _fav(id: '2', name: '卵')];

      final result = filterNewFavorites(selected, const []);

      expect(result.length, 2);
    });

    test('選択が空の場合は空リストを返す', () {
      final activeItems = [_item(id: 'a', name: '牛乳')];

      final result = filterNewFavorites(const [], activeItems);

      expect(result, isEmpty);
    });

    test('前後の空白を除去して正規化した名前で重複判定する', () {
      final selected = [_fav(id: '1', name: '  牛乳  ')];
      final activeItems = [_item(id: 'a', name: '牛乳')];

      final result = filterNewFavorites(selected, activeItems);

      expect(result, isEmpty);
    });

    test('大文字小文字を無視して重複判定する', () {
      final selected = [_fav(id: '1', name: 'Milk')];
      final activeItems = [_item(id: 'a', name: 'milk')];

      final result = filterNewFavorites(selected, activeItems);

      expect(result, isEmpty);
    });

    test('連続空白を 1 スペースに圧縮して重複判定する', () {
      final selected = [_fav(id: '1', name: '牛　乳')]; // 全角スペース
      final activeItems = [_item(id: 'a', name: '牛 乳')]; // 半角スペース

      // 全角スペースは \s にマッチするため正規化後は同一になる
      final result = filterNewFavorites(selected, activeItems);

      expect(result, isEmpty);
    });

    test('購入済みアイテムは重複判定から除外する', () {
      final selected = [_fav(id: '1', name: '牛乳')];
      final activeItems = [
        _item(id: 'a', name: '牛乳', status: ItemStatus.purchased),
      ];

      final result = filterNewFavorites(selected, activeItems);

      // 購入済みは除外されるため重複なし → 追加対象になる
      expect(result.length, 1);
    });

    test('重複しないものだけを返す（混在ケース）', () {
      final selected = [
        _fav(id: '1', name: '牛乳'),
        _fav(id: '2', name: '卵'),
        _fav(id: '3', name: 'パン'),
      ];
      final activeItems = [
        _item(id: 'a', name: '牛乳'),
        _item(id: 'b', name: 'パン'),
      ];

      final result = filterNewFavorites(selected, activeItems);

      expect(result.length, 1);
      expect(result.first.id, '2');
    });
  });
}
