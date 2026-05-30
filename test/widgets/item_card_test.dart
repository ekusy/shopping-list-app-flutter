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

    await tester.tap(find.text('🗑️'));
    await tester.pump();
    expect(deleted, isTrue);
  });

  testWidgets('購入済みアイテムは未購入に戻すアイコンを表示する', (tester) async {
    await pumpLocalized(
      tester,
      ItemCard(
        item: _item(status: ItemStatus.purchased),
        onSetVolunteer: (_) {},
        onSetPurchased: (_) {},
        onDelete: () {},
      ),
    );

    // 購入済みでは「買うよ」ボタンが消え、未購入に戻すアイコン（↩）が出る。
    expect(find.text('↩'), findsOneWidget);
    expect(find.text('🙋'), findsNothing);
  });
}
