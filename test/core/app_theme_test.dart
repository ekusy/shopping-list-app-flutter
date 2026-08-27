import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/theme/app_theme.dart';
import 'package:shopping_list_app/core/theme/font_license.dart';

/// 日本語表示に必要なフォント同梱（#75）が外れていないことを守るテスト。
///
/// Web（CanvasKit）は OS のシステムフォントへフォールバックしないため、
/// `fontFamily` の指定や pubspec.yaml の fonts セクションが失われると
/// 日本語がすべて tofu（□）になる。ビルドは通ってしまうので回帰に気づけない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildAppTheme', () {
    test('同梱フォント NotoSansJP を既定フォントに設定している', () {
      expect(buildAppTheme().textTheme.bodyMedium?.fontFamily, 'NotoSansJP');
    });
  });

  group('バンドルフォント', () {
    test('Regular / Bold の両ウェイトが pubspec.yaml に登録されている', () async {
      for (final weight in ['Regular', 'Bold']) {
        final data = await rootBundle.load(
          'assets/fonts/NotoSansJP-$weight.v1.ttf',
        );
        expect(
          data.lengthInBytes,
          greaterThan(0),
          reason: 'NotoSansJP-$weight.v1.ttf がアセットとして解決できない',
        );
      }
    });

    test('OFL ライセンス全文が LicenseRegistry に登録される', () async {
      LicenseRegistry.reset();
      registerBundledFontLicenses();

      final entries = await LicenseRegistry.licenses.toList();
      final fontEntry = entries.firstWhere(
        (e) => e.packages.contains('NotoSansJP'),
        orElse: () => throw StateError('NotoSansJP のライセンスが未登録'),
      );

      final text = fontEntry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(text, contains('PERMISSION & CONDITIONS'));

      LicenseRegistry.reset();
    });
  });
}
