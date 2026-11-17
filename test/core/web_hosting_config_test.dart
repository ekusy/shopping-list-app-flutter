import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firebase Hosting のキャッシュ設定（`firebase.json`）が Flutter Web の
/// ビルド出力仕様と整合していることを検証する（#98）。
///
/// Flutter Web は `main.dart.js` / `flutter_bootstrap.js` 等のファイル名に
/// コンテンツハッシュを付与せず、かつ Flutter 3.44 で Service Worker の
/// キャッシュ機能が廃止されたため、`immutable` を付与するとデプロイ後の
/// 更新が既存ユーザーに届かなくなる。
void main() {
  final firebaseConfig =
      jsonDecode(File('firebase.json').readAsStringSync())
          as Map<String, dynamic>;
  final hosting = firebaseConfig['hosting'] as Map<String, dynamic>;
  final headerRules = (hosting['headers'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  String? cacheControlForSource(String source) {
    for (final rule in headerRules) {
      if (rule['source'] == source) {
        final headers = (rule['headers'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final header in headers) {
          if (header['key'] == 'Cache-Control') {
            return header['value'] as String?;
          }
        }
      }
    }
    return null;
  }

  group('firebase.json hosting.headers (#98)', () {
    test('ルート / と /index.html の双方に Cache-Control: no-cache が設定されている', () {
      expect(cacheControlForSource('/'), equals('no-cache'));
      expect(cacheControlForSource('/index.html'), equals('no-cache'));
    });

    test('JS / CSS / WASM に Cache-Control: no-cache が設定されている', () {
      expect(cacheControlForSource('**/*.@(js|css|wasm)'), equals('no-cache'));
    });

    test('/flutter_service_worker.js に Cache-Control: no-cache が設定されている', () {
      expect(
        cacheControlForSource('/flutter_service_worker.js'),
        equals('no-cache'),
      );
    });

    test('ハッシュ無しのビルド成果物に対して immutable が設定されていない', () {
      for (final rule in headerRules) {
        final headers = (rule['headers'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final header in headers) {
          if (header['key'] == 'Cache-Control') {
            final value = header['value'] as String;
            expect(
              value.contains('immutable'),
              isFalse,
              reason:
                  'source "${rule['source']}" has Cache-Control "$value" containing immutable',
            );
          }
        }
      }
    });
  });
}
