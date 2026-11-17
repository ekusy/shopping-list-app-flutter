import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/theme/app_theme.dart';

String _colorToHex(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// プラットフォーム間のアプリ名・テーマカラー設定が Kaimono ブランドおよび
/// [AppColors] トークンと一致していることを検証する（#93）。
void main() {
  group('ブランド設定の一貫性 (#93)', () {
    test('web/manifest.json のアプリ名とカラーが AppColors と一致する', () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, dynamic>;

      expect(manifest['name'], equals('Kaimono'));
      expect(manifest['short_name'], equals('Kaimono'));
      expect(
        (manifest['theme_color'] as String).toUpperCase(),
        equals(_colorToHex(AppColors.primary)),
      );
      expect(
        (manifest['background_color'] as String).toUpperCase(),
        equals(_colorToHex(AppColors.background)),
      );
    });

    test('AndroidManifest.xml の android:label が Kaimono である', () {
      final androidManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(androidManifest, contains('android:label="Kaimono"'));
    });

    test('ios/Runner/Info.plist の CFBundleDisplayName が Kaimono である', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        RegExp(
          r'<key>CFBundleDisplayName</key>\s*<string>Kaimono</string>',
        ).hasMatch(infoPlist),
        isTrue,
      );
    });
  });
}
