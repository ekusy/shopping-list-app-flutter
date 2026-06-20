import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/utils/name_key.dart';

void main() {
  group('normalizeName', () {
    test('前後の空白を除去する', () {
      expect(normalizeName('  牛乳  '), '牛乳');
    });

    test('前後の空白を除去する（タブ・改行含む）', () {
      expect(normalizeName('\t牛乳\n'), '牛乳');
    });

    test('連続する空白（半角）を 1 つに圧縮する', () {
      expect(normalizeName('牛乳  パン'), '牛乳 パン');
    });

    test('連続する空白（複数種混在）を 1 つに圧縮する', () {
      expect(normalizeName('牛乳 \t パン'), '牛乳 パン');
    });

    test('小文字化する（ASCII）', () {
      expect(normalizeName('MILK'), 'milk');
    });

    test('小文字化する（混在）', () {
      expect(normalizeName('Apple Juice'), 'apple juice');
    });

    test('トリム後に「牛乳」と「牛乳 」が同一正規化になる', () {
      expect(normalizeName('牛乳'), equals(normalizeName('牛乳 ')));
    });

    test('前後空白除去と連続空白圧縮を組み合わせる', () {
      expect(normalizeName('  牛乳  パン  '), '牛乳 パン');
    });

    test('空文字列はそのまま空文字列', () {
      expect(normalizeName(''), '');
    });

    test('空白のみは空文字列になる', () {
      expect(normalizeName('   '), '');
    });

    test('日本語はそのまま（NFKC 未対応）', () {
      // NFKC 未適用のため全角英字はそのまま
      expect(normalizeName('ＡＢＣＤ'), 'ａｂｃｄ');
    });
  });
}
