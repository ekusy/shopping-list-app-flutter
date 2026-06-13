/**
 * Item name normalization and key derivation for
 * `groups/{groupId}/purchaseHistorySummaries/{nameKey}`.
 *
 * Spec: docs/ドラフト/AI提案機能/01-履歴データ設計.md §4
 *
 * Algorithm (MUST stay in sync with any future Dart-side implementation,
 * e.g. Issue #43 「よく買う物リスト」):
 *   1. Unicode NFKC normalization (full-width alnum -> half-width,
 *      half-width kana -> full-width kana, etc.)
 *   2. Trim leading/trailing whitespace and collapse runs of internal
 *      whitespace into a single space.
 *   3. Lowercase (`toLowerCase()`).
 *   4. Hash the result with SHA-1 and encode as base64url to obtain the
 *      Firestore document ID (avoids `/` and length issues with raw
 *      product names). The raw display text is kept separately in the
 *      `name` field — this function only derives the key.
 *
 * This module has no dependency on `firebase-functions` / `firebase-admin`
 * so it can be unit-tested directly and ported to other runtimes.
 */
import { createHash } from "crypto";

/**
 * Normalize a raw item name for use as a summary grouping key.
 *
 * See module doc comment for the exact algorithm steps.
 */
export function normalizeName(raw: string): string {
  return raw
    .normalize("NFKC")
    .trim()
    .replace(/\s+/g, " ")
    .toLowerCase();
}

/**
 * Derive the `purchaseHistorySummaries` document ID for a raw item name.
 *
 * `base64url(SHA-1(normalizeName(raw)))`.
 */
export function nameKeyOf(raw: string): string {
  const normalized = normalizeName(raw);
  return createHash("sha1").update(normalized, "utf8").digest("base64url");
}
