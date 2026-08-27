import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 同梱フォントのライセンス全文が置かれているアセットパス。
const String kBundledFontLicenseAsset = 'assets/fonts/OFL.txt';

/// 同梱フォント（Noto Sans JP / SIL Open Font License 1.1）のライセンスを登録する。
///
/// SIL OFL はフォントの再配布時にライセンス全文の同梱を求めている。
/// [LicenseRegistry] に登録しておくと `showLicensePage()` から全文を参照できる。
///
/// 収録文字・再生成手順は `assets/fonts/README.md` を参照（#75）。
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(kBundledFontLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['NotoSansJP'], license);
  });
}
