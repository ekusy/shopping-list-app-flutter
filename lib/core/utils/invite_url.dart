import 'package:flutter/foundation.dart' show kIsWeb;

/// 招待リンクのカスタムスキーム（Native フォールバック）。
const String _appScheme = 'shoppinglistapp';

/// ビルド時に `--dart-define=APP_URL=...` で渡せる招待リンクのベース URL。
/// 元実装の `EXPO_PUBLIC_APP_URL` に相当する。
const String _envAppUrl = String.fromEnvironment('APP_URL');

/// 招待リンクの URL を生成する。
///
/// 優先順:
/// 1. `--dart-define=APP_URL` が設定されていればそのドメインを利用
/// 2. Web: `Uri.base.origin`
/// 3. Native: カスタムスキーム `shoppinglistapp://group/join?code=XXX`
///
/// @param code 招待コード（8 文字英数字）
/// @returns 招待リンクの URL
String buildInviteUrl(String code) {
  final trimmedCode = code.trim();
  if (_envAppUrl.isNotEmpty) {
    return _joinPath(_envAppUrl, trimmedCode);
  }
  if (kIsWeb) {
    return _joinPath(Uri.base.origin, trimmedCode);
  }
  return '$_appScheme://group/join?code=${Uri.encodeComponent(trimmedCode)}';
}

/// ベース URL の末尾スラッシュを除いて `/group/join?code=XXX` を結合する。
String _joinPath(String base, String code) {
  final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$normalized/group/join?code=${Uri.encodeComponent(code)}';
}
