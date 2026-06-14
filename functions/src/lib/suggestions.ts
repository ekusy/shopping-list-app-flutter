/**
 * Pure business logic for the weekly AI suggestion pipeline (Issue #40 Phase 1).
 *
 * Spec: docs/ドラフト/AI提案機能/02-週次提案パイプライン設計.md
 *
 * This module has no dependency on `firebase-functions` / `firebase-admin` /
 * `@google/genai`. All timestamps are represented as epoch milliseconds; the
 * data layer (`src/data/suggestions_store.ts`) is responsible for converting
 * to/from `firebase-admin` `Timestamp`, and the Gemini I/O layer
 * (`src/data/gemini_client.ts`) is responsible for the actual model call.
 */
import { nameKeyOf } from "./name_key";

/** Retention period for `suggestions` documents (Firestore TTL target). */
export const SUGGESTIONS_EXPIRES_DAYS = 90;

/** Minimum number of `purchaseHistorySummaries` entries required to generate suggestions. */
export const MIN_SUMMARIES_FOR_SUGGESTIONS = 3;

/** Maximum number of items returned in each of `forgottenItems` / `recommendedItems`. */
export const MAX_SUGGESTION_ITEMS = 5;

/** Maximum length (in characters) of each suggestion's `reason` field. */
export const MAX_REASON_LENGTH = 100;

/** Number of weeks of `itemHistory` events included in the prompt. */
export const HISTORY_WEEKS = 8;

/** Number of top `purchaseHistorySummaries` entries (by `purchaseCount`) included in the prompt. */
export const TOP_SUMMARIES_COUNT = 30;

/**
 * Fixed offset (ms) from UTC to JST (UTC+9, no DST).
 *
 * The whole feature is JST-fixed (#33: Saturday 08:00 JST schedule, Japanese
 * output), so all *calendar* derivations (week id, "today" label, "最終購入日")
 * must use the JST wall-clock, not UTC. The scheduler fires at 08:00 JST,
 * which is 23:00 UTC the previous day — deriving calendar fields from UTC
 * would yield the wrong date/day-of-week (and at week/year boundaries, the
 * wrong week id). Shifting the epoch-ms by this offset and then reading UTC
 * getters reproduces the JST wall-clock deterministically without depending
 * on the host timezone.
 */
export const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

/**
 * Returns a `Date` whose UTC getters read out the JST wall-clock for the
 * given instant. Use only with `getUTC*` accessors; the absolute instant is
 * intentionally shifted and must not be used for arithmetic against real
 * timestamps.
 */
function jstWallClock(epochMs: number): Date {
  return new Date(epochMs + JST_OFFSET_MS);
}

/**
 * ISO week id for the JST wall-clock at `epochMs`, e.g. `'2026-W24'`.
 *
 * This is what callers should use to derive `suggestions/{weekId}`: the
 * Saturday-08:00-JST run must map to the ISO week of that JST Saturday, not
 * of the underlying UTC instant (which is the previous day).
 */
export function isoWeekIdJst(epochMs: number): string {
  return isoWeekId(jstWallClock(epochMs));
}

/** `M/D` label (JST) for the given instant, e.g. `'6/13'`. */
function formatJstMonthDay(epochMs: number): string {
  const d = jstWallClock(epochMs);
  return `${d.getUTCMonth() + 1}/${d.getUTCDate()}`;
}

/** `YYYY/M/D` label (JST) for the given instant, e.g. `'2026/6/13'`. */
export function formatJstTodayLabel(epochMs: number): string {
  const d = jstWallClock(epochMs);
  return `${d.getUTCFullYear()}/${d.getUTCMonth() + 1}/${d.getUTCDate()}`;
}

/** `groups/{groupId}/suggestions/{weekId}` confidence level for `forgottenItems`. */
export type SuggestionConfidence = "high" | "medium" | "low";

export interface ForgottenItemSuggestion {
  name: string;
  reason: string;
  confidence: SuggestionConfidence;
}

export interface RecommendedItemSuggestion {
  name: string;
  reason: string;
}

/** Status of a generated `suggestions/{weekId}` document. */
export type SuggestionStatus = "ready" | "empty";

/** Validated/post-processed result, ready to be persisted by the data layer. */
export interface ProcessedSuggestions {
  status: SuggestionStatus;
  forgottenItems: ForgottenItemSuggestion[];
  recommendedItems: RecommendedItemSuggestion[];
}

/** Raw (unvalidated) structured output returned by Gemini. */
export interface RawSuggestionsResponse {
  forgottenItems?: unknown;
  recommendedItems?: unknown;
}

/**
 * Returns the ISO 8601 week identifier for `date`, e.g. `'2026-W24'`.
 *
 * Uses the standard ISO week-numbering algorithm: weeks start on Monday, and
 * week 1 is the week containing the year's first Thursday. The returned week
 * number is always 2 digits (zero-padded).
 */
export function isoWeekId(date: Date): string {
  // Copy and normalize to UTC midnight to avoid timezone/DST drift while
  // shifting days.
  const target = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );

  // ISO weekday: Monday = 1 ... Sunday = 7.
  const isoWeekday = target.getUTCDay() === 0 ? 7 : target.getUTCDay();

  // Shift to the Thursday of this ISO week; the ISO week-numbering year is
  // the year that Thursday falls in.
  target.setUTCDate(target.getUTCDate() - isoWeekday + 4);
  const isoYear = target.getUTCFullYear();

  // Week 1 is the week containing the year's first Thursday, i.e. the week
  // containing January 4th.
  const jan4 = new Date(Date.UTC(isoYear, 0, 4));
  const jan4Weekday = jan4.getUTCDay() === 0 ? 7 : jan4.getUTCDay();
  const week1Monday = new Date(jan4);
  week1Monday.setUTCDate(jan4.getUTCDate() - jan4Weekday + 1);

  const diffDays = Math.round(
    (target.getTime() - week1Monday.getTime()) / (24 * 60 * 60 * 1000),
  );
  const weekNumber = Math.floor(diffDays / 7) + 1;

  return `${isoYear}-W${String(weekNumber).padStart(2, "0")}`;
}

/** `generatedAt + SUGGESTIONS_EXPIRES_DAYS` expressed in epoch milliseconds. */
export function computeSuggestionsExpiresAt(generatedAtMs: number): number {
  return generatedAtMs + SUGGESTIONS_EXPIRES_DAYS * 24 * 60 * 60 * 1000;
}

/** A single `itemHistory` event, compressed to the fields needed for prompt-building. */
export interface HistoryEventInput {
  type: "purchased" | "deleted";
  name: string;
  statusAtDeletion?: string;
  /** Epoch milliseconds. */
  occurredAtMs: number;
}

/** A single `purchaseHistorySummaries` entry, with derived average cycle days. */
export interface SummaryInput {
  name: string;
  purchaseCount: number;
  /** Epoch milliseconds. */
  lastPurchasedAt?: number;
  totalCycleDays: number;
}

/** A single active (unpurchased) item on the group's current list. */
export interface ActiveItemInput {
  name: string;
  tagName?: string;
}

/** Aggregated input for one group, used by both skip-detection and prompt building. */
export interface GroupSuggestionInput {
  activeItems: ActiveItemInput[];
  historyEvents: HistoryEventInput[];
  summaries: SummaryInput[];
  /** "now" as epoch milliseconds, used to bound the "recent 1 week" window. */
  nowMs: number;
}

/**
 * Returns true iff the group should be skipped (Gemini is not called) per
 * 02 §2.1:
 *
 * - The last 1 week has zero `itemHistory` events (dormant group: no
 *   purchases or deletions to analyze), OR
 * - `summaries` has fewer than `MIN_SUMMARIES_FOR_SUGGESTIONS` entries
 *   (too little history to ground a suggestion).
 *
 * `itemHistory` events are recorded for both purchases and deletions
 * (`src/lib/history.ts`), so "recent itemHistory activity" is used as the
 * single activity signal — it captures the "新規追加" half of 02 §2.1 in
 * practice, since newly-added items eventually surface as `purchased` or
 * `deleted` events.
 */
export function shouldSkipGroup(input: GroupSuggestionInput): boolean {
  if (input.summaries.length < MIN_SUMMARIES_FOR_SUGGESTIONS) {
    return true;
  }

  const oneWeekAgoMs = input.nowMs - 7 * 24 * 60 * 60 * 1000;
  const hasRecentHistoryEvent = input.historyEvents.some(
    (event) => event.occurredAtMs >= oneWeekAgoMs,
  );

  return !hasRecentHistoryEvent;
}

/**
 * Compress `historyEvents` into per-week summary lines, e.g.
 * `"W21: 牛乳 購入, 卵 購入, ティッシュ 削除(未購入)"`.
 *
 * Events are grouped by `isoWeekId` and rendered in chronological order
 * (oldest week first). Within a week, events are rendered in the order they
 * appear in `events`. `purchased` events render as `"{name} 購入"`;
 * `deleted` events render as `"{name} 削除(未購入)"` only when
 * `statusAtDeletion === 'active'` (i.e. removed without ever being
 * purchased) — `deleted` events for already-purchased items carry no
 * additional signal and are omitted.
 */
export function compressHistoryByWeek(events: HistoryEventInput[]): string[] {
  const weekMap = new Map<string, string[]>();

  for (const event of events) {
    let label: string | undefined;
    if (event.type === "purchased") {
      label = `${event.name} 購入`;
    } else if (event.type === "deleted" && event.statusAtDeletion === "active") {
      label = `${event.name} 削除(未購入)`;
    }
    if (label === undefined) continue;

    const weekId = isoWeekIdJst(event.occurredAtMs);
    const existing = weekMap.get(weekId);
    if (existing) {
      existing.push(label);
    } else {
      weekMap.set(weekId, [label]);
    }
  }

  const sortedWeekIds = Array.from(weekMap.keys()).sort();
  return sortedWeekIds.map((weekId) => {
    const labels = weekMap.get(weekId)!;
    // weekId is like "2026-W24"; the prompt format only shows "W24".
    const shortWeekId = weekId.slice(weekId.indexOf("W"));
    return `${shortWeekId}: ${labels.join(", ")}`;
  });
}

/**
 * Format the "よく買う商品" line for one summary entry, e.g.
 * `"牛乳: 12回 / 約7日ごと / 最終 6/3"`.
 *
 * The average cycle is `totalCycleDays / (purchaseCount - 1)` when
 * `purchaseCount >= 2` (there is at least one observed gap); otherwise the
 * cycle is omitted ("初回" — not enough data). `lastPurchasedAt` is omitted
 * if absent. The "最終" date is rendered in JST (see `JST_OFFSET_MS`).
 */
export function formatSummaryLine(summary: SummaryInput): string {
  const parts = [`${summary.purchaseCount}回`];

  if (summary.purchaseCount >= 2) {
    const avgCycleDays = summary.totalCycleDays / (summary.purchaseCount - 1);
    parts.push(`約${Math.round(avgCycleDays)}日ごと`);
  }

  if (summary.lastPurchasedAt !== undefined) {
    parts.push(`最終 ${formatJstMonthDay(summary.lastPurchasedAt)}`);
  }

  return `${summary.name}: ${parts.join(" / ")}`;
}

/** Format the "現在の買い物リスト" line for one active item, e.g. `"牛乳（タグ: 急ぎ）"`. */
export function formatActiveItemLine(item: ActiveItemInput): string {
  return item.tagName ? `${item.name}（タグ: ${item.tagName}）` : item.name;
}

/**
 * Fixed system instruction for the Gemini call (cacheable). Defines the
 * model's role, output language, judgment criteria, output schema semantics,
 * and prohibitions.
 *
 * Spec: 02 §3.1.
 */
export const SYSTEM_INSTRUCTION = `あなたは家族・グループ向け買い物リストアプリの買い物アドバイザーです。
ユーザーの購買履歴データを分析し、「購入忘れの可能性がある商品」と
「次の買い物で買うとよさそうな商品」を提案してください。

出力は必ず日本語で記述してください。

判断基準:
- 「購入忘れ」は、平均購入間隔から見て次の購入時期を過ぎている、または
  間近に迫っているにもかかわらず現在のリストに含まれていない商品を指します。
- 「次の購入候補」は、購入履歴のパターンから今後必要になりそうな商品を指します。
- 表記ゆれ（例:「牛乳」と「明治おいしい牛乳」）は同一商品として扱ってください。

禁止事項:
- 現在の買い物リストに既に含まれている商品を提案してはいけません。
- 購入履歴やリストに全く根拠のない商品を提案してはいけません。
- forgottenItems / recommendedItems はそれぞれ最大5件、reasonは100字程度の
  簡潔な1文としてください。

出力は指定された JSON スキーマに厳密に従ってください。`;

/**
 * Build the dynamic user prompt for one group (02 §3.1).
 *
 * `todayLabel` is the pre-formatted "today" string (e.g. `"2026/6/13"`),
 * computed by the caller so this function stays free of `Date`-formatting
 * concerns tied to a specific timezone.
 */
export function buildUserPrompt(input: {
  todayLabel: string;
  activeItems: ActiveItemInput[];
  summaries: SummaryInput[];
  historyEvents: HistoryEventInput[];
}): string {
  const activeItemsSection =
    input.activeItems.length > 0
      ? input.activeItems.map((item) => `- ${formatActiveItemLine(item)}`).join("\n")
      : "（なし）";

  const summariesSection =
    input.summaries.length > 0
      ? input.summaries.map((summary) => `- ${formatSummaryLine(summary)}`).join("\n")
      : "（なし）";

  const historyLines = compressHistoryByWeek(input.historyEvents);
  const historySection = historyLines.length > 0 ? historyLines.join("\n") : "（なし）";

  return `今日は ${input.todayLabel} です。

【現在の買い物リスト（未購入）】
${activeItemsSection}

【よく買う商品（累計購入回数・平均購入間隔・最終購入日）】
${summariesSection}

【直近${HISTORY_WEEKS}週間の購入・削除イベント（週単位）】
${historySection}

この家族の購買パターンを分析し、(1) 平均購入間隔から考えてそろそろ切れるはずなのに
リストに無い商品（購入忘れの可能性）、(2) 次の買い物で買うとよさそうな商品、を提案してください。
表記ゆれ（例: 「牛乳」と「明治おいしい牛乳」）は同一商品として扱ってください。`;
}

/**
 * JSON schema for Gemini's `responseSchema` config (structured output).
 *
 * Spec: 02 §3.2.
 */
export const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    forgottenItems: {
      type: "array",
      maxItems: MAX_SUGGESTION_ITEMS,
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          reason: { type: "string" },
          confidence: {
            type: "string",
            enum: ["high", "medium", "low"],
          },
        },
        required: ["name", "reason", "confidence"],
      },
    },
    recommendedItems: {
      type: "array",
      maxItems: MAX_SUGGESTION_ITEMS,
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          reason: { type: "string" },
        },
        required: ["name", "reason"],
      },
    },
  },
  required: ["forgottenItems", "recommendedItems"],
} as const;

function isValidConfidence(value: unknown): value is SuggestionConfidence {
  return value === "high" || value === "medium" || value === "low";
}

function truncateReason(reason: string): string {
  return reason.length > MAX_REASON_LENGTH
    ? reason.slice(0, MAX_REASON_LENGTH)
    : reason;
}

/**
 * Validate and post-process Gemini's raw structured-output response (02 §3.3):
 *
 * - Items whose `nameKey` matches an item already on the active list
 *   (`activeNameKeys`) are excluded.
 * - Each array is capped at `MAX_SUGGESTION_ITEMS` entries (after exclusion).
 * - Each `reason` is truncated to `MAX_REASON_LENGTH` characters.
 * - Malformed entries (missing/invalid required fields) are dropped.
 * - If both resulting arrays are empty, `status` is `'empty'`; otherwise `'ready'`.
 */
export function validateAndPostProcess(
  raw: RawSuggestionsResponse,
  activeNameKeys: ReadonlySet<string>,
): ProcessedSuggestions {
  const rawForgotten = Array.isArray(raw.forgottenItems) ? raw.forgottenItems : [];
  const rawRecommended = Array.isArray(raw.recommendedItems)
    ? raw.recommendedItems
    : [];

  const forgottenItems: ForgottenItemSuggestion[] = [];
  for (const entry of rawForgotten) {
    if (forgottenItems.length >= MAX_SUGGESTION_ITEMS) break;
    if (
      typeof entry !== "object" ||
      entry === null ||
      typeof (entry as Record<string, unknown>).name !== "string" ||
      typeof (entry as Record<string, unknown>).reason !== "string" ||
      !isValidConfidence((entry as Record<string, unknown>).confidence)
    ) {
      continue;
    }
    const name = (entry as { name: string }).name;
    if (activeNameKeys.has(nameKeyOf(name))) continue;

    forgottenItems.push({
      name,
      reason: truncateReason((entry as { reason: string }).reason),
      confidence: (entry as { confidence: SuggestionConfidence }).confidence,
    });
  }

  const recommendedItems: RecommendedItemSuggestion[] = [];
  for (const entry of rawRecommended) {
    if (recommendedItems.length >= MAX_SUGGESTION_ITEMS) break;
    if (
      typeof entry !== "object" ||
      entry === null ||
      typeof (entry as Record<string, unknown>).name !== "string" ||
      typeof (entry as Record<string, unknown>).reason !== "string"
    ) {
      continue;
    }
    const name = (entry as { name: string }).name;
    if (activeNameKeys.has(nameKeyOf(name))) continue;

    recommendedItems.push({
      name,
      reason: truncateReason((entry as { reason: string }).reason),
    });
  }

  const status: SuggestionStatus =
    forgottenItems.length === 0 && recommendedItems.length === 0
      ? "empty"
      : "ready";

  return { status, forgottenItems, recommendedItems };
}
