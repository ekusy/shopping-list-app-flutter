import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 翻訳 JSON をディスクから**同期的に**読み込む [AssetLoader]。
///
/// 既定の [RootBundleAssetLoader] は非同期で `rootBundle` を読むため、
/// 1 ファイル内で複数のウィジェットテストを実行すると 2 件目以降で
/// `Localizations` のロード Future が `pumpAndSettle` 中に解決されず、
/// 画面が空のまま（子ウィジェットが見つからない）になる既知の問題がある。
/// [SynchronousFuture] を返すことでロードを同期化し、毎回確実に描画させる。
class _SyncTranslationLoader extends AssetLoader {
  const _SyncTranslationLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) {
    final file = File('$path/${locale.languageCode}.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return SynchronousFuture<Map<String, dynamic>>(data);
  }
}

/// ウィジェットテストで `easy_localization` を初期化する。
/// `setUpAll` から一度だけ呼ぶ。
Future<void> setUpTestLocalization() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

/// [child] を `easy_localization` + [MaterialApp] でラップして描画する。
///
/// 同期ローダーを使うため、同一ファイル内の複数テストでも安定して描画される。
///
/// [locale] を渡すとその言語に固定する（既定はテスト端末ロケール。テスト端末は
/// 通常 `en` のため、日本語の文言を検証する場合は `const Locale('ja')` を渡す）。
///
/// [wrapper] を渡すと、[MaterialApp] を含むツリー全体をさらにラップできる。
/// `showModalBottomSheet` 等が root Navigator のオーバーレイ（MaterialApp 直下）に
/// 描画されても `ProviderScope` 祖先を見つけられるよう、本番（main.dart）と同じ
/// 「ProviderScope が MaterialApp を包む」構造にしたいモーダル系テストで使う。
/// 例: `wrapper: (app) => ProviderScope(overrides: [...], child: app)`。
/// （`Override` 型はインラインのリスト literal の型推論で解決させるため、本ヘルパーは
/// 型名に依存しない `wrapper` 方式を採る。）
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale? locale,
  Widget Function(Widget app)? wrapper,
}) async {
  Widget app = EasyLocalization(
    supportedLocales: const [Locale('ja'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('ja'),
    startLocale: locale,
    assetLoader: const _SyncTranslationLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(body: child),
      ),
    ),
  );
  if (wrapper != null) {
    app = wrapper(app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}
