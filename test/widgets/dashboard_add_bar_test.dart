import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/theme/app_theme.dart';
import 'package:shopping_list_app/domain/entities/group.dart';
import 'package:shopping_list_app/domain/entities/tag.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/widgets/add_item_form.dart';
import 'package:shopping_list_app/presentation/widgets/dashboard/dashboard_add_bar.dart';
import 'package:shopping_list_app/presentation/widgets/quick_add_input.dart';

import '../helpers/test_localization.dart';

Group _group() => Group(
  id: 'g1',
  name: 'テストグループ',
  ownerId: 'u1',
  memberIds: const ['u1'],
  inviteCode: 'INVITE1',
);

Future<void> _pumpAddBar(WidgetTester tester, {Group? group}) async {
  await pumpLocalized(
    tester,
    const DashboardAddBar(),
    locale: const Locale('ja'),
    wrapper: (app) => ProviderScope(
      overrides: [
        activeGroupProvider.overrideWithValue(group),
        tagsProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
      ],
      child: app,
    ),
  );
}

void main() {
  setUpAll(() async {
    await setUpTestLocalization();
  });

  testWidgets('クイック追加とインディゴ FAB が同一行に横並び表示される', (tester) async {
    await _pumpAddBar(tester, group: _group());

    expect(find.byType(QuickAddInput), findsOneWidget);
    final fabFinder = find.byKey(const Key('dashboard_detail_add_fab'));
    expect(fabFinder, findsOneWidget);

    final fab = tester.widget<FloatingActionButton>(fabFinder);
    expect(fab.backgroundColor, AppColors.primary);
    expect(fab.onPressed, isNotNull);

    // QuickAddInput と FAB がほぼ同じ Y 座標（1 行）に配置されていること。
    final quickAddCenterY = tester.getCenter(find.byType(QuickAddInput)).dy;
    final fabCenterY = tester.getCenter(fabFinder).dy;
    expect((quickAddCenterY - fabCenterY).abs(), lessThan(8.0));
  });

  testWidgets('FAB タップで詳細追加モーダルが開く', (tester) async {
    await _pumpAddBar(tester, group: _group());

    await tester.tap(find.byKey(const Key('dashboard_detail_add_fab')));
    await tester.pumpAndSettle();

    expect(find.byType(AddItemForm), findsOneWidget);
  });

  testWidgets('グループ未所属時は FAB が無効化される', (tester) async {
    await _pumpAddBar(tester, group: null);

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('dashboard_detail_add_fab')),
    );
    expect(fab.onPressed, isNull);
  });
}
