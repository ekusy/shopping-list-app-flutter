import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/item.dart';
import 'package:shopping_list_app/presentation/widgets/item_card.dart';

import '../helpers/test_localization.dart';

Item _item({ItemStatus? status}) => Item(
  id: 'i1',
  name: 'Milk',
  category: '',
  note: 'note text',
  imageUrl: '',
  status: status ?? ItemStatus.active,
);

void main() {
  setUpAll(setUpTestLocalization);

  testWidgets('アイテム名とメモを表示する', (tester) async {
    await pumpLocalized(
      tester,
      ItemCard(
        item: _item(),
        onSetVolunteer: (_) {},
        onSetPurchased: (_) {},
        onDelete: () {},
      ),
    );

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('note text'), findsOneWidget);
  });

  testWidgets('削除ボタンで onDelete を呼ぶ', (tester) async {
    var deleted = false;
    await pumpLocalized(
      tester,
      ItemCard(
        item: _item(),
        onSetVolunteer: (_) {},
        onSetPurchased: (_) {},
        onDelete: () => deleted = true,
      ),
    );

    // InkWell の内訳: チェックボックス(IconButton) + 買うよ + 購入済 + 削除 = 4。
    // 末尾が削除ボタン。
    final buttons = find.byType(InkWell);
    expect(buttons, findsNWidgets(4));
    await tester.tap(buttons.last);
    await tester.pump();
    expect(deleted, isTrue);
  });

  testWidgets('編集・削除ボタンは視認性の高い Material アイコンで表示する', (tester) async {
    await pumpLocalized(
      tester,
      ItemCard(
        item: _item(),
        onSetVolunteer: (_) {},
        onSetPurchased: (_) {},
        onDelete: () {},
        onEdit: () {},
      ),
    );

    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('編集ボタンで onEdit を呼ぶ', (tester) async {
    var edited = false;
    await pumpLocalized(
      tester,
      ItemCard(
        item: _item(),
        onSetVolunteer: (_) {},
        onSetPurchased: (_) {},
        onDelete: () {},
        onEdit: () => edited = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    expect(edited, isTrue);
  });

  testWidgets('購入済みアイテムは「買うよ」ボタンを隠し、戻すと onSetPurchased(false) を呼ぶ', (
    tester,
  ) async {
    bool? purchasedArg;
    await pumpLocalized(
      tester,
      ItemCard(
        item: _item(status: ItemStatus.purchased),
        onSetVolunteer: (_) {},
        onSetPurchased: (v) => purchasedArg = v,
        onDelete: () {},
      ),
    );

    // InkWell の内訳: チェックボックス(IconButton) + 戻す + 削除 = 3。
    // 「買うよ」は isBought=true で非表示。at(1) が「戻す」ボタン。
    final buttons = find.byType(InkWell);
    expect(buttons, findsNWidgets(3));
    await tester.tap(buttons.at(1));
    await tester.pump();
    expect(purchasedArg, isFalse);
  });

  testWidgets('状態に応じた背景ウォッシュ（通常/自分ボランティア/他メンバー/購入済み）を適用する', (tester) async {
    Future<Color?> pumpAndGetBg(Item item) async {
      await pumpLocalized(
        tester,
        ItemCard(
          item: item,
          currentUid: 'me',
          memberNames: const {'other': 'Bob'},
          onSetVolunteer: (_) {},
          onSetPurchased: (_) {},
          onDelete: () {},
        ),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      return (container.decoration as BoxDecoration?)?.color;
    }

    expect(await pumpAndGetBg(_item()), const Color(0xFFFFFFFF));
    expect(
      await pumpAndGetBg(
        Item(
          id: 'i2',
          name: 'Bread',
          category: '',
          note: '',
          imageUrl: '',
          status: ItemStatus.active,
          buyingBy: 'me',
        ),
      ),
      const Color(0xFFFCEEDD),
    );
    expect(
      await pumpAndGetBg(
        Item(
          id: 'i3',
          name: 'Eggs',
          category: '',
          note: '',
          imageUrl: '',
          status: ItemStatus.active,
          buyingBy: 'other',
        ),
      ),
      const Color(0xFFE3F2FD),
    );
    expect(
      await pumpAndGetBg(_item(status: ItemStatus.purchased)),
      const Color(0xFFE6F5EE),
    );
  });
}
