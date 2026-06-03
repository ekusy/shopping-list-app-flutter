import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/utils/invite_code.dart';

void main() {
  group('generateInviteCode', () {
    test('8 文字の大文字英数字を生成する', () {
      for (var i = 0; i < 50; i++) {
        final code = generateInviteCode();
        expect(code.length, 8);
        expect(
          RegExp(r'^[0-9A-Z]{8}$').hasMatch(code),
          isTrue,
          reason: 'unexpected code: $code',
        );
      }
    });

    test('複数回呼ぶと（ほぼ確実に）異なるコードになる', () {
      final codes = {for (var i = 0; i < 20; i++) generateInviteCode()};
      expect(codes.length, greaterThan(1));
    });
  });
}
