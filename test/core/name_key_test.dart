import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/utils/name_key.dart';

/// Dart / TypeScript 双方のテストが読む共通フィクスチャ（#88）。
///
/// TS 側は `functions/src/lib/name_key.test.ts` が同じファイルを読む。
/// 片側だけを更新すると必ずもう一方のテストが落ちるため、両実装の乖離を防げる。
const _fixturePath = 'test/fixtures/name_normalization_cases.json';

void main() {
  final fixture =
      jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;
  final cases = (fixture['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  group('normalizeName（TS 実装との共通フィクスチャ）', () {
    test('フィクスチャが読み込めている', () {
      expect(cases, isNotEmpty);
    });

    for (final testCase in cases) {
      test(testCase['description'] as String, () {
        expect(
          normalizeName(testCase['input'] as String),
          testCase['expected'] as String,
        );
      });
    }
  });

  group('normalizeName（同一視の性質）', () {
    test('トリム後に「牛乳」と「牛乳 」が同一正規化になる', () {
      expect(normalizeName('牛乳'), equals(normalizeName('牛乳 ')));
    });

    test('全角英字と半角英字が同一正規化になる（#88 の再現ケース）', () {
      expect(normalizeName('ＡＢＣ牛乳'), equals(normalizeName('ABC牛乳')));
    });

    test('半角カナと全角カナが同一正規化になる', () {
      expect(normalizeName('ﾐﾙｸ'), equals(normalizeName('ミルク')));
    });

    test('全角スペース区切りと半角スペース区切りが同一正規化になる', () {
      expect(normalizeName('牛乳　パン'), equals(normalizeName('牛乳 パン')));
    });

    test('異なる商品は別の正規化結果になる', () {
      expect(normalizeName('牛乳'), isNot(equals(normalizeName('豆乳'))));
    });
  });
}
