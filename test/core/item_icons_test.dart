import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/utils/item_icons.dart';

void main() {
  group('getItemIcons', () {
    test('ja でデフォルトアイコンを返す', () {
      final icons = getItemIcons('ja');
      expect(icons.volunteer, '🙋');
      expect(icons.bought, '✅');
      expect(icons.delete, '🗑️');
    });

    test('未知の言語でもデフォルトを返す', () {
      final icons = getItemIcons('xx');
      expect(icons.pendingSync, '⏳');
    });
  });
}
