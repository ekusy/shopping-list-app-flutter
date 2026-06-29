import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/presentation/widgets/quick_add_input.dart';

import '../helpers/test_localization.dart';

void main() {
  setUpAll(() async {
    await setUpTestLocalization();
  });

  testWidgets('onDetailAdd 未指定のとき詳細追加アイコンを表示しない', (tester) async {
    await pumpLocalized(
      tester,
      QuickAddInput(onAdd: (_) async {}),
      locale: const Locale('ja'),
    );

    expect(find.byKey(const Key('quick_add_detail_button')), findsNothing);
  });

  testWidgets('onDetailAdd 指定時に詳細追加アイコンを表示しタップでコールバックする', (tester) async {
    var detailTapped = false;
    await pumpLocalized(
      tester,
      QuickAddInput(
        onAdd: (_) async {},
        onDetailAdd: () => detailTapped = true,
      ),
      locale: const Locale('ja'),
    );

    final detailButton = find.byKey(const Key('quick_add_detail_button'));
    expect(detailButton, findsOneWidget);

    await tester.tap(detailButton);
    await tester.pumpAndSettle();

    expect(detailTapped, isTrue);
  });

  testWidgets('テキスト入力 + 追加ボタンで onAdd が呼ばれる', (tester) async {
    String? added;
    await pumpLocalized(
      tester,
      QuickAddInput(onAdd: (name) async => added = name),
      locale: const Locale('ja'),
    );

    await tester.enterText(find.byType(TextField), '牛乳');
    // 追加ボタン（FilledButton、ラベルは i18n キーが返る）をタップ。
    await tester.tap(find.widgetWithText(FilledButton, 'form.add_button'));
    await tester.pumpAndSettle();

    expect(added, '牛乳');
  });

  testWidgets('disabled のとき入力・追加が無効化される', (tester) async {
    var addCalled = false;
    await pumpLocalized(
      tester,
      QuickAddInput(onAdd: (_) async => addCalled = true, disabled: true),
      locale: const Locale('ja'),
    );

    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'form.add_button'),
    );
    expect(addButton.onPressed, isNull);
    expect(addCalled, isFalse);
  });
}
