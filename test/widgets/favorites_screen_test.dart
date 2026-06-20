import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/favorite_item.dart';
import 'package:shopping_list_app/domain/entities/tag.dart';
import 'package:shopping_list_app/presentation/providers/favorite_providers.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/screens/favorites/favorites_screen.dart';

import '../helpers/test_localization.dart';

// ---------------------------------------------------------------------------
// テスト用ファクトリ
// ---------------------------------------------------------------------------

FavoriteItem _fav({required String id, required String name, int order = 0}) =>
    FavoriteItem(
      id: id,
      name: name,
      note: '',
      imageUrl: '',
      order: order,
      addedBy: 'user1',
    );

// ---------------------------------------------------------------------------
// ヘルパー: 画面を描画する
// ---------------------------------------------------------------------------

/// よく買う物画面を、テスト用ローカライズ + Riverpod override で描画する。
///
/// `.tr()` はウィジェットテストではキーをそのまま返す（翻訳値は解決されない）ため、
/// 本テストは**構造・データ**（ウィジェット型 / アイコン / Key）で検証し、
/// 翻訳済み文言には依存しない。
Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<FavoriteItem> favorites,
}) async {
  // ProviderScope は MaterialApp の上位に置く（wrapper 経由）。こうしないと
  // showModalBottomSheet（root Navigator のオーバーレイ）が ProviderScope 祖先を
  // 見つけられず「No ProviderScope found」になる。
  await pumpLocalized(
    tester,
    const FavoritesScreen(),
    locale: const Locale('ja'),
    wrapper: (app) => ProviderScope(
      overrides: [
        favoritesProvider.overrideWith((ref) => Stream.value(favorites)),
        // 追加モーダルが watch する tagsProvider を空で差し替え、
        // 実プロバイダ（group/auth/Firebase）連鎖に触れずにモーダルを描画する。
        tagsProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
      ],
      child: app,
    ),
  );
}

// ---------------------------------------------------------------------------
// テスト本体
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await setUpTestLocalization();
  });

  testWidgets('よく買う物が空のとき空状態アイコンを表示する', (tester) async {
    await _pumpScreen(tester, favorites: const []);

    // 空状態のキーを確認
    expect(find.byKey(const Key('favorites_empty')), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_outline), findsWidgets);
  });

  testWidgets('よく買う物が存在するとき一覧を描画する', (tester) async {
    final favorites = [
      _fav(id: '1', name: '牛乳', order: 0),
      _fav(id: '2', name: '卵', order: 1),
    ];

    await _pumpScreen(tester, favorites: favorites);

    expect(find.byKey(const Key('favorites_list')), findsOneWidget);
    // アイテム名が描画されている
    expect(find.text('牛乳'), findsOneWidget);
    expect(find.text('卵'), findsOneWidget);
  });

  testWidgets('アイテムをタップすると選択モードになり下部バーが表示される', (tester) async {
    final favorites = [_fav(id: '1', name: '牛乳')];

    await _pumpScreen(tester, favorites: favorites);

    // 選択バー・下部バーは初期状態では非表示
    expect(find.byKey(const Key('favorites_selection_bar')), findsNothing);
    expect(find.byKey(const Key('favorites_add_to_list_bar')), findsNothing);

    // チェックボックスアイコンをタップして選択
    await tester.tap(find.byKey(const Key('favorite_select_1')));
    await tester.pumpAndSettle();

    // 選択モードになると選択バーと下部バーが表示される
    expect(find.byKey(const Key('favorites_selection_bar')), findsOneWidget);
    expect(find.byKey(const Key('favorites_add_to_list_bar')), findsOneWidget);
    expect(
      find.byKey(const Key('favorites_add_to_list_button')),
      findsOneWidget,
    );
  });

  testWidgets('「全選択」ボタンで全アイテムが選択される', (tester) async {
    final favorites = [
      _fav(id: '1', name: '牛乳', order: 0),
      _fav(id: '2', name: '卵', order: 1),
    ];

    await _pumpScreen(tester, favorites: favorites);

    // 1件を選択して選択モードに入る
    await tester.tap(find.byKey(const Key('favorite_select_1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('favorites_select_all_button')),
      findsOneWidget,
    );

    // 全選択ボタンをタップ
    await tester.tap(find.byKey(const Key('favorites_select_all_button')));
    await tester.pumpAndSettle();

    // 両方のチェックが ☑ になっていることを確認（Text ウィジェットの ☑ が 2 件）
    expect(find.text('☑'), findsNWidgets(2));
  });

  testWidgets('追加ボタンが AppBar に表示される', (tester) async {
    await _pumpScreen(tester, favorites: const []);

    expect(find.byKey(const Key('favorites_add_button')), findsOneWidget);
  });

  testWidgets('編集・削除ボタンが各カードに表示される（非選択モード）', (tester) async {
    final favorites = [_fav(id: '1', name: '牛乳')];

    await _pumpScreen(tester, favorites: favorites);

    expect(find.byKey(const Key('favorite_edit_1')), findsOneWidget);
    expect(find.byKey(const Key('favorite_delete_1')), findsOneWidget);
  });

  testWidgets('選択モードでは編集・削除ボタンが非表示になる', (tester) async {
    final favorites = [_fav(id: '1', name: '牛乳')];

    await _pumpScreen(tester, favorites: favorites);

    // 選択モードに入る
    await tester.tap(find.byKey(const Key('favorite_select_1')));
    await tester.pumpAndSettle();

    // 選択モードでは編集・削除ボタンは非表示
    expect(find.byKey(const Key('favorite_edit_1')), findsNothing);
    expect(find.byKey(const Key('favorite_delete_1')), findsNothing);
  });

  testWidgets('追加モーダルに写真ボタン・名前・メモ入力が含まれる', (tester) async {
    await _pumpScreen(tester, favorites: const []);

    // AppBar の追加ボタンを押してモーダルを開く
    await tester.tap(find.byKey(const Key('favorites_add_button')));
    await tester.pumpAndSettle();

    // 直接追加フォームに写真アップロードボタンが存在する（#43 画像対応）
    expect(find.byKey(const Key('favorite_photo_button')), findsOneWidget);
    expect(find.byKey(const Key('favorite_name_field')), findsOneWidget);
    expect(find.byKey(const Key('favorite_note_field')), findsOneWidget);
    expect(find.byKey(const Key('favorite_save_button')), findsOneWidget);
  });
}
