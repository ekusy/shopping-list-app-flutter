// アイテム名の正規化ユーティリティ。
// `functions/src/lib/name_key.ts` の `normalizeName` と**同一のアルゴリズム**を実装する。
// 重複判定（よく買う物テンプレートとアクティブアイテム名との突合）に使う。
//
// 両実装の出力一致は `test/fixtures/name_normalization_cases.json` を
// Dart / TypeScript 双方のテストが読むことで担保している（#88）。
// アルゴリズムを変更する場合は必ず両方の実装とフィクスチャを同時に更新すること。
//
// TS 側にある `nameKeyOf`（`base64url(SHA-1(normalizeName(raw)))`）は Dart へ移植していない。
// `nameKey` は `groups/{groupId}/purchaseHistorySummaries/{nameKey}` のドキュメント ID 専用で、
// クライアントはこのコレクションを読まない（購入履歴画面 #42 が読むのは `itemHistory`）ため。
// クライアントからサマリーを直接引く必要が生じた時点で移植する。

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// アイテム名を正規化する（重複判定用）。
///
/// 処理内容（`functions/src/lib/name_key.ts` の `normalizeName` と同順・同内容）:
///   1. Unicode NFKC 正規化（全角英数→半角、半角カナ→全角カナ、全角スペース→半角スペース等）
///   2. 前後の空白を除去（`trim`）
///   3. 連続する空白を 1 つに圧縮（`\s` は ECMAScript 準拠で全角スペース等も含む）
///   4. 小文字化（`toLowerCase`）
///
/// Dart の標準ライブラリに Unicode 正規化が無いため NFKC は `unorm_dart` で行う
/// （純 Dart 実装のため Web / Android / iOS すべてで動作する）。
String normalizeName(String raw) {
  return unorm.nfkc(raw).trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
