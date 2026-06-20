// アイテム名の正規化ユーティリティ。
// `functions/src/lib/name_key.ts` の `normalizeName` のサブセット。
// NFKC 正規化（全角英数→半角等の畳み込み）と SHA-1 ハッシュ化（nameKey 生成）は
// 本 MVP では未対応。重複判定（よく買う物テンプレートのアクティブアイテム名との突合）に使う想定。

/// アイテム名を正規化する（重複判定用）。
///
/// 処理内容:
///   1. 前後の空白を除去（`trim`。全角スペース U+3000 等の Unicode 空白も対象）
///   2. 連続する空白を 1 つに圧縮（`\s` は全角スペースを含む）
///   3. 小文字化（`toLowerCase`）
///
/// **TODO**: `functions/src/lib/name_key.ts` の `normalizeName` に合わせ、
/// 将来的に NFKC 正規化（全角英数→半角、半角カナ→全角カナ等）を追加する予定。
/// 現時点では全角英数（例: `ＡＢＣ`）が半角へ畳み込まれないなど、TS 版との
/// 完全な同期は取れていない点に注意すること。
String normalizeName(String raw) {
  return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
