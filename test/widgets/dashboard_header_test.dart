import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/group.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/providers/item_providers.dart';
import 'package:shopping_list_app/presentation/providers/suggestion_providers.dart';
import 'package:shopping_list_app/presentation/widgets/dashboard/dashboard_header.dart';

import '../helpers/test_localization.dart';

// ---------------------------------------------------------------------------
// テスト用ファクトリ / ヘルパー
// ---------------------------------------------------------------------------

Group _group(String name) => Group(
  id: 'g1',
  name: name,
  ownerId: 'u1',
  memberIds: const ['u1'],
  inviteCode: 'INVITE1',
);

/// `DashboardHeader` を、必要な provider を override して描画する。
///
/// `.tr()` はウィジェットテストではキーをそのまま返すため、文言ではなく
/// **構造（アイコン / Key の有無）** で検証する。Firebase 連鎖に触れないよう、
/// ヘッダーが直接 watch する 3 つの provider をすべて override する。
Future<void> _pumpHeader(
  WidgetTester tester, {
  Group? group,
  int pendingCount = 0,
  bool unread = false,
}) async {
  await pumpLocalized(
    tester,
    DashboardHeader(onOpenMenu: () {}),
    locale: const Locale('ja'),
    wrapper: (app) => ProviderScope(
      overrides: [
        activeGroupProvider.overrideWithValue(group),
        pendingItemCountProvider.overrideWithValue(pendingCount),
        hasUnreadSuggestionProvider.overrideWith((ref) => Future.value(unread)),
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

  testWidgets('二次アクション（タグ管理 / よく買う物）はヘッダーに表示しない', (tester) async {
    await _pumpHeader(tester, group: _group('わが家'));

    // タグ管理・よく買う物はサイドバーへ移動したのでヘッダーには無い。
    expect(find.text('tag.manage'), findsNothing);
    expect(find.byIcon(Icons.bookmark_outline), findsNothing);

    // AI 提案ボタンとメニューボタンはヘッダーに残る。
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('長いグループ名でもタイトルとして描画される', (tester) async {
    await _pumpHeader(tester, group: _group('とてもながいグループめい'));

    expect(find.text('とてもながいグループめい'), findsOneWidget);
  });

  testWidgets('グループ未所属時はアプリ名をタイトルにフォールバックする', (tester) async {
    await _pumpHeader(tester, group: null);

    expect(find.text('app.title'), findsOneWidget);
  });

  testWidgets('未読提案があるとき未読バッジを表示する', (tester) async {
    await _pumpHeader(tester, group: _group('わが家'), unread: true);

    expect(find.byKey(const Key('dashboard_unread_badge')), findsOneWidget);
  });

  testWidgets('未読提案が無いとき未読バッジを表示しない', (tester) async {
    await _pumpHeader(tester, group: _group('わが家'), unread: false);

    expect(find.byKey(const Key('dashboard_unread_badge')), findsNothing);
  });

  testWidgets('未購入件数が 0 より大きいとき件数テキストを表示する', (tester) async {
    await _pumpHeader(tester, group: _group('わが家'), pendingCount: 3);

    expect(find.textContaining('status.pending_count'), findsOneWidget);
  });
}
