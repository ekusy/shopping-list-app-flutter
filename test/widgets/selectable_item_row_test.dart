import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/item.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/widgets/dashboard/selectable_item_row.dart';

import '../helpers/test_localization.dart';

Item _item(String id, String name) => Item(
  id: id,
  name: name,
  category: '',
  note: '',
  imageUrl: '',
  status: ItemStatus.active,
);

Future<void> _pumpRow(WidgetTester tester, {required Item item}) async {
  await pumpLocalized(
    tester,
    SelectableItemRow(
      item: item,
      currentUid: 'u1',
      memberNames: const {},
      onSetVolunteer: (_) {},
      onSetPurchased: (_) {},
      onEdit: () {},
      onDelete: () {},
    ),
    locale: const Locale('ja'),
    // activeGroupIdProvider を固定し、SelectionController が Firebase 連鎖に
    // 触れずにビルドできるようにする。
    wrapper: (app) => ProviderScope(
      overrides: [activeGroupIdProvider.overrideWithValue('g1')],
      child: app,
    ),
  );
}

void main() {
  setUpAll(() async {
    await setUpTestLocalization();
  });

  testWidgets('未選択時は ☐ を表示し、タップで選択され ☑ になる', (tester) async {
    await _pumpRow(tester, item: _item('a', '牛乳'));

    expect(find.text('☐'), findsOneWidget);
    expect(find.text('☑'), findsNothing);

    // チェックボックスをタップ → toggle → 選択状態が ItemCard に反映される。
    await tester.tap(find.text('☐'));
    await tester.pumpAndSettle();

    expect(find.text('☑'), findsOneWidget);
    expect(find.text('☐'), findsNothing);
  });
}
