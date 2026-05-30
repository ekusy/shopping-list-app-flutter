import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/item.dart';

Item _item({
  ItemStatus? status,
  bool? isBought,
  String? buyingBy,
  String? buyerId,
}) {
  return Item(
    id: 'i1',
    name: 'milk',
    category: '',
    note: '',
    imageUrl: '',
    status: status,
    isBought: isBought,
    buyingBy: buyingBy,
    buyerId: buyerId,
  );
}

void main() {
  group('Item.isPurchased', () {
    test('status == purchased で true', () {
      expect(_item(status: ItemStatus.purchased).isPurchased, isTrue);
    });
    test('旧 isBought == true で true（互換）', () {
      expect(_item(isBought: true).isPurchased, isTrue);
    });
    test('active で false', () {
      expect(_item(status: ItemStatus.active).isPurchased, isFalse);
    });
  });

  group('Item.volunteerUid / isBeingBought', () {
    test('buyingBy を優先する', () {
      final i = _item(buyingBy: 'u1', buyerId: 'u2');
      expect(i.volunteerUid, 'u1');
      expect(i.isBeingBought, isTrue);
    });
    test('buyingBy が無ければ旧 buyerId をフォールバック', () {
      expect(_item(buyerId: 'u2').volunteerUid, 'u2');
    });
    test('どちらも無ければ null', () {
      expect(_item().volunteerUid, isNull);
      expect(_item().isBeingBought, isFalse);
    });
  });

  group('ItemStatus.fromCode', () {
    test('文字列を解決する', () {
      expect(ItemStatus.fromCode('active'), ItemStatus.active);
      expect(ItemStatus.fromCode('purchased'), ItemStatus.purchased);
      expect(ItemStatus.fromCode('unknown'), isNull);
      expect(ItemStatus.fromCode(null), isNull);
    });
  });
}
