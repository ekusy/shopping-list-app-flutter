import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// クリップボード・OS 共有シートのユーティリティ（旧 clipboard / shareInvite）。
class ShareHelper {
  ShareHelper._();

  /// テキストをクリップボードにコピーする。
  static Future<void> copyToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  /// OS の共有シートでテキストを共有する。
  static Future<void> shareText(String text, {String? subject}) {
    return SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}
