import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/utils/invite_url.dart';

void main() {
  group('buildInviteUrl', () {
    // VM テスト（非 Web）では kIsWeb=false かつ APP_URL 未設定のため
    // カスタムスキームの URL を生成する。
    test('Native フォールバックでスキーム URL を生成する', () {
      final url = buildInviteUrl('ABCD1234');
      expect(url, 'shoppinglistapp://group/join?code=ABCD1234');
    });

    test('コードはトリム + URL エンコードされる', () {
      final url = buildInviteUrl('  AB CD  ');
      expect(url, 'shoppinglistapp://group/join?code=AB%20CD');
    });
  });
}
