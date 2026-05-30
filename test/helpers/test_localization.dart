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
Future<void> pumpLocalized(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('ja'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ja'),
      assetLoader: const _SyncTranslationLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
