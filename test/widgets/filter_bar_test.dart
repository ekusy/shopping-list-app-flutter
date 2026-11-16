import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/item.dart';
import 'package:shopping_list_app/domain/entities/tag.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/providers/selection_controller.dart';
import 'package:shopping_list_app/presentation/widgets/filter_bar.dart';
import 'package:shopping_list_app/presentation/widgets/shopping_list.dart';

import '../helpers/test_localization.dart';

List<Container> _findColorDots(WidgetTester tester, Color color) {
  return tester.widgetList<Container>(find.byType(Container)).where((c) {
    final dec = c.decoration;
    return dec is BoxDecoration &&
        dec.shape == BoxShape.circle &&
        dec.color == color &&
        c.constraints?.maxWidth == 8 &&
        c.constraints?.maxHeight == 8;
  }).toList();
}

void main() {
  setUpAll(() async {
    await setUpTestLocalization();
  });

  test('tagColor は同じ tagId に対して決定論的に同じ色を返し、null にはスレートを返す', () {
    expect(tagColor(null), const Color(0xFF78909C));
    expect(tagColor(''), const Color(0xFF78909C));
    expect(tagColor('tag-urgent'), tagColor('tag-urgent'));
  });

  testWidgets('「すべて」チップにはドットがなく、タグチップにカラードットが表示される', (tester) async {
    const tags = [
      Tag(id: 'tag-1', name: '急ぎ', order: 0),
      Tag(id: 'tag-2', name: 'まとめ買い', order: 1),
    ];

    String? toggled;
    var cleared = false;

    await pumpLocalized(
      tester,
      FilterBar(
        tags: tags,
        selectedTagIds: const ['tag-1'],
        onToggle: (id) => toggled = id,
        onClear: () => cleared = true,
      ),
      locale: const Locale('ja'),
    );

    // 「すべて」チップ内に円形ドットが存在しないこと。
    final allChip = find.ancestor(
      of: find.text('common.all'),
      matching: find.byType(GestureDetector),
    );
    final dotsInAll = tester
        .widgetList<Container>(
          find.descendant(of: allChip, matching: find.byType(Container)),
        )
        .where((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.shape == BoxShape.circle;
        });
    expect(dotsInAll, isEmpty);

    // 各タグチップ内に tagColor(tag.id) の 8x8 ドットが存在すること。
    expect(_findColorDots(tester, tagColor('tag-1')), isNotEmpty);
    expect(_findColorDots(tester, tagColor('tag-2')), isNotEmpty);

    await tester.tap(find.text('まとめ買い'));
    expect(toggled, 'tag-2');

    await tester.tap(find.text('common.all'));
    expect(cleared, isTrue);
  });

  testWidgets('タグが10件あっても横スクロールでオーバーフローしない', (tester) async {
    final tags = List.generate(
      10,
      (i) => Tag(id: 'tag-$i', name: 'タグ$i', order: i),
    );

    await pumpLocalized(
      tester,
      FilterBar(
        tags: tags,
        selectedTagIds: const [],
        onToggle: (_) {},
        onClear: () {},
      ),
      locale: const Locale('ja'),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ShoppingList のセクションヘッダーにチップと同じカラードットが表示される', (tester) async {
    const tag = Tag(id: 'tag-urgent', name: '急ぎ', order: 0);
    const item = Item(
      id: 'item-1',
      name: '牛乳',
      category: '',
      note: '',
      imageUrl: '',
      tagId: 'tag-urgent',
      order: 0,
      status: ItemStatus.active,
      addedBy: 'u1',
    );

    await pumpLocalized(
      tester,
      ShoppingList(
        items: const [item],
        onSetVolunteer: (_, _) {},
        onSetPurchased: (_, _) {},
        onEdit: (_) {},
        onDelete: (_) {},
        onClearPurchased: () {},
        onDeleteSection: (_) {},
      ),
      locale: const Locale('ja'),
      wrapper: (app) => ProviderScope(
        overrides: [
          tagsProvider.overrideWith((ref) => Stream.value(const [tag])),
          selectionActiveProvider.overrideWithValue(false),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();

    expect(_findColorDots(tester, tagColor('tag-urgent')), hasLength(1));
  });
}
