import { describe, expect, it } from "vitest";
import {
  buildUserPrompt,
  compressHistoryByWeek,
  computeSuggestionsExpiresAt,
  formatActiveItemLine,
  formatJstTodayLabel,
  formatSummaryLine,
  isoWeekId,
  isoWeekIdJst,
  MAX_REASON_LENGTH,
  MAX_SUGGESTION_ITEMS,
  MIN_SUMMARIES_FOR_SUGGESTIONS,
  shouldSkipGroup,
  SUGGESTIONS_EXPIRES_DAYS,
  validateAndPostProcess,
  type GroupSuggestionInput,
  type HistoryEventInput,
  type RawSuggestionsResponse,
  type SummaryInput,
} from "./suggestions";
import { nameKeyOf } from "./name_key";

const DAY_MS = 24 * 60 * 60 * 1000;

describe("isoWeekId", () => {
  it("computes the ISO week number for a mid-year date", () => {
    // 2026-06-13 is a Saturday in ISO week 24 of 2026.
    expect(isoWeekId(new Date(Date.UTC(2026, 5, 13)))).toBe("2026-W24");
  });

  it("handles the first week of January belonging to the previous ISO year", () => {
    // 2027-01-01 is a Friday. ISO week containing Jan 1 2027 -> its Thursday
    // is also in Dec 2026's ISO year... Use a well-known case instead:
    // 2023-01-01 (Sunday) belongs to ISO week 2022-W52.
    expect(isoWeekId(new Date(Date.UTC(2023, 0, 1)))).toBe("2022-W52");
  });

  it("handles a date whose ISO week belongs to the next year", () => {
    // 2025-12-29 (Monday) is the first day of ISO week 2026-W01.
    expect(isoWeekId(new Date(Date.UTC(2025, 11, 29)))).toBe("2026-W01");
  });

  it("zero-pads single-digit week numbers", () => {
    // 2026-01-01 (Thursday) is in ISO week 2026-W01.
    expect(isoWeekId(new Date(Date.UTC(2026, 0, 1)))).toBe("2026-W01");
  });
});

describe("isoWeekIdJst / formatJstTodayLabel", () => {
  // The scheduler fires at 08:00 JST, which is 23:00 UTC the previous day.
  // Calendar derivations must reflect the JST wall-clock, not UTC.
  const SAT_0800_JST = Date.UTC(2026, 5, 13, 8 - 9, 0, 0); // 2026-06-12 23:00 UTC

  it("derives the JST calendar date for an instant whose UTC date differs", () => {
    // The underlying UTC date is 2026-06-12 (Friday); the JST date is 2026-06-13.
    expect(formatJstTodayLabel(SAT_0800_JST)).toBe("2026/6/13");
    // Sanity: a naive UTC reading would have produced the wrong date.
    expect(new Date(SAT_0800_JST).getUTCDate()).toBe(12);
  });

  it("uses the JST week id (not the UTC instant's week)", () => {
    expect(isoWeekIdJst(SAT_0800_JST)).toBe("2026-W24");
  });

  it("handles a year-boundary Saturday run in JST", () => {
    // 2027-01-02 08:00 JST is ISO week 2026-W53.
    const ms = Date.UTC(2027, 0, 2, 8 - 9, 0, 0);
    expect(formatJstTodayLabel(ms)).toBe("2027/1/2");
    expect(isoWeekIdJst(ms)).toBe("2026-W53");
  });
});

describe("computeSuggestionsExpiresAt", () => {
  it("adds SUGGESTIONS_EXPIRES_DAYS in milliseconds", () => {
    const generatedAt = 1_000_000;
    expect(computeSuggestionsExpiresAt(generatedAt)).toBe(
      generatedAt + SUGGESTIONS_EXPIRES_DAYS * DAY_MS,
    );
  });

  it("uses 90 days", () => {
    expect(SUGGESTIONS_EXPIRES_DAYS).toBe(90);
  });
});

describe("shouldSkipGroup", () => {
  const now = Date.UTC(2026, 5, 13); // 2026-06-13

  const enoughSummaries: SummaryInput[] = [
    { name: "牛乳", purchaseCount: 5, totalCycleDays: 28 },
    { name: "卵", purchaseCount: 4, totalCycleDays: 21 },
    { name: "パン", purchaseCount: 3, totalCycleDays: 14 },
  ];

  it("skips when summaries has fewer than MIN_SUMMARIES_FOR_SUGGESTIONS entries", () => {
    const input: GroupSuggestionInput = {
      activeItems: [],
      historyEvents: [
        { type: "purchased", name: "牛乳", occurredAtMs: now - DAY_MS },
      ],
      summaries: enoughSummaries.slice(0, MIN_SUMMARIES_FOR_SUGGESTIONS - 1),
      nowMs: now,
    };
    expect(shouldSkipGroup(input)).toBe(true);
  });

  it("skips when there are no itemHistory events in the last 7 days (dormant group)", () => {
    const input: GroupSuggestionInput = {
      activeItems: [],
      historyEvents: [
        { type: "purchased", name: "牛乳", occurredAtMs: now - 8 * DAY_MS },
      ],
      summaries: enoughSummaries,
      nowMs: now,
    };
    expect(shouldSkipGroup(input)).toBe(true);
  });

  it("does not skip when there is recent history and enough summaries", () => {
    const input: GroupSuggestionInput = {
      activeItems: [],
      historyEvents: [
        { type: "purchased", name: "牛乳", occurredAtMs: now - DAY_MS },
      ],
      summaries: enoughSummaries,
      nowMs: now,
    };
    expect(shouldSkipGroup(input)).toBe(false);
  });

  it("treats an event exactly 7 days old as within the recent window", () => {
    const input: GroupSuggestionInput = {
      activeItems: [],
      historyEvents: [
        { type: "purchased", name: "牛乳", occurredAtMs: now - 7 * DAY_MS },
      ],
      summaries: enoughSummaries,
      nowMs: now,
    };
    expect(shouldSkipGroup(input)).toBe(false);
  });

  it("skips when there is no history at all", () => {
    const input: GroupSuggestionInput = {
      activeItems: [],
      historyEvents: [],
      summaries: enoughSummaries,
      nowMs: now,
    };
    expect(shouldSkipGroup(input)).toBe(true);
  });
});

describe("compressHistoryByWeek", () => {
  it("groups purchased and deleted(active) events by ISO week, in chronological order", () => {
    const events: HistoryEventInput[] = [
      // W24 2026 (2026-06-13 Sat)
      { type: "purchased", name: "牛乳", occurredAtMs: Date.UTC(2026, 5, 13) },
      {
        type: "deleted",
        name: "ティッシュ",
        statusAtDeletion: "active",
        occurredAtMs: Date.UTC(2026, 5, 13),
      },
      // W23 2026 (2026-06-06 Sat)
      { type: "purchased", name: "卵", occurredAtMs: Date.UTC(2026, 5, 6) },
    ];

    expect(compressHistoryByWeek(events)).toEqual([
      "W23: 卵 購入",
      "W24: 牛乳 購入, ティッシュ 削除(未購入)",
    ]);
  });

  it("omits deleted events for items that were already purchased", () => {
    const events: HistoryEventInput[] = [
      {
        type: "deleted",
        name: "牛乳",
        statusAtDeletion: "purchased",
        occurredAtMs: Date.UTC(2026, 5, 13),
      },
    ];
    expect(compressHistoryByWeek(events)).toEqual([]);
  });

  it("returns an empty array for no events", () => {
    expect(compressHistoryByWeek([])).toEqual([]);
  });
});

describe("formatSummaryLine", () => {
  it("formats a summary with multiple purchases and a last-purchased date", () => {
    const summary: SummaryInput = {
      name: "牛乳",
      purchaseCount: 12,
      totalCycleDays: 77, // 11 gaps -> ~7 days
      lastPurchasedAt: Date.UTC(2026, 5, 3),
    };
    expect(formatSummaryLine(summary)).toBe("牛乳: 12回 / 約7日ごと / 最終 6/3");
  });

  it("omits the cycle when purchaseCount is 1 (no observed gap)", () => {
    const summary: SummaryInput = {
      name: "海苔",
      purchaseCount: 1,
      totalCycleDays: 0,
      lastPurchasedAt: Date.UTC(2026, 5, 1),
    };
    expect(formatSummaryLine(summary)).toBe("海苔: 1回 / 最終 6/1");
  });

  it("omits the last-purchased date when absent", () => {
    const summary: SummaryInput = {
      name: "牛乳",
      purchaseCount: 1,
      totalCycleDays: 0,
    };
    expect(formatSummaryLine(summary)).toBe("牛乳: 1回");
  });
});

describe("formatActiveItemLine", () => {
  it("includes the tag name when present", () => {
    expect(formatActiveItemLine({ name: "牛乳", tagName: "急ぎ" })).toBe(
      "牛乳（タグ: 急ぎ）",
    );
  });

  it("omits the tag annotation when absent", () => {
    expect(formatActiveItemLine({ name: "牛乳" })).toBe("牛乳");
  });
});

describe("buildUserPrompt", () => {
  it("includes today's date, active items, summaries, and compressed history", () => {
    const prompt = buildUserPrompt({
      todayLabel: "2026/6/13",
      activeItems: [{ name: "牛乳", tagName: "急ぎ" }],
      summaries: [{ name: "牛乳", purchaseCount: 12, totalCycleDays: 77, lastPurchasedAt: Date.UTC(2026, 5, 3) }],
      historyEvents: [
        { type: "purchased", name: "卵", occurredAtMs: Date.UTC(2026, 5, 6) },
      ],
    });

    expect(prompt).toContain("今日は 2026/6/13 です。");
    expect(prompt).toContain("牛乳（タグ: 急ぎ）");
    expect(prompt).toContain("牛乳: 12回 / 約7日ごと / 最終 6/3");
    expect(prompt).toContain("W23: 卵 購入");
  });

  it("renders placeholders for empty sections", () => {
    const prompt = buildUserPrompt({
      todayLabel: "2026/6/13",
      activeItems: [],
      summaries: [],
      historyEvents: [],
    });

    const placeholderCount = prompt.split("（なし）").length - 1;
    expect(placeholderCount).toBe(3);
  });
});

describe("validateAndPostProcess", () => {
  const noActiveItems = new Set<string>();

  it("passes through valid entries within limits", () => {
    const raw: RawSuggestionsResponse = {
      forgottenItems: [
        { name: "牛乳", reason: "そろそろ切れる頃です", confidence: "high" },
      ],
      recommendedItems: [{ name: "卵", reason: "よく一緒に買われています" }],
    };

    const result = validateAndPostProcess(raw, noActiveItems);
    expect(result.status).toBe("ready");
    expect(result.forgottenItems).toEqual([
      { name: "牛乳", reason: "そろそろ切れる頃です", confidence: "high" },
    ]);
    expect(result.recommendedItems).toEqual([
      { name: "卵", reason: "よく一緒に買われています" },
    ]);
  });

  it("excludes items already on the active list (nameKey match)", () => {
    const raw: RawSuggestionsResponse = {
      forgottenItems: [
        { name: "牛乳", reason: "そろそろ切れる頃です", confidence: "high" },
        { name: "卵", reason: "そろそろ切れる頃です", confidence: "medium" },
      ],
      recommendedItems: [],
    };
    const activeNameKeys = new Set([nameKeyOf("牛乳")]);

    const result = validateAndPostProcess(raw, activeNameKeys);
    expect(result.forgottenItems).toEqual([
      { name: "卵", reason: "そろそろ切れる頃です", confidence: "medium" },
    ]);
  });

  it("caps each array at MAX_SUGGESTION_ITEMS entries", () => {
    const makeItems = (n: number) =>
      Array.from({ length: n }, (_, i) => ({
        name: `商品${i}`,
        reason: "reason",
        confidence: "low" as const,
      }));

    const raw: RawSuggestionsResponse = {
      forgottenItems: makeItems(MAX_SUGGESTION_ITEMS + 3),
      recommendedItems: makeItems(MAX_SUGGESTION_ITEMS + 3).map(({ name, reason }) => ({
        name,
        reason,
      })),
    };

    const result = validateAndPostProcess(raw, noActiveItems);
    expect(result.forgottenItems).toHaveLength(MAX_SUGGESTION_ITEMS);
    expect(result.recommendedItems).toHaveLength(MAX_SUGGESTION_ITEMS);
  });

  it("truncates reason text longer than MAX_REASON_LENGTH", () => {
    const longReason = "あ".repeat(MAX_REASON_LENGTH + 20);
    const raw: RawSuggestionsResponse = {
      forgottenItems: [{ name: "牛乳", reason: longReason, confidence: "low" }],
      recommendedItems: [],
    };

    const result = validateAndPostProcess(raw, noActiveItems);
    expect(result.forgottenItems[0].reason).toHaveLength(MAX_REASON_LENGTH);
  });

  it("returns status 'empty' when both arrays end up empty", () => {
    const raw: RawSuggestionsResponse = {
      forgottenItems: [],
      recommendedItems: [],
    };
    const result = validateAndPostProcess(raw, noActiveItems);
    expect(result.status).toBe("empty");
    expect(result.forgottenItems).toEqual([]);
    expect(result.recommendedItems).toEqual([]);
  });

  it("returns status 'empty' when all entries are excluded as already-active", () => {
    const raw: RawSuggestionsResponse = {
      forgottenItems: [{ name: "牛乳", reason: "reason", confidence: "high" }],
      recommendedItems: [{ name: "牛乳", reason: "reason" }],
    };
    const activeNameKeys = new Set([nameKeyOf("牛乳")]);

    const result = validateAndPostProcess(raw, activeNameKeys);
    expect(result.status).toBe("empty");
  });

  it("drops malformed entries (missing fields, invalid confidence) without throwing", () => {
    const raw: RawSuggestionsResponse = {
      forgottenItems: [
        { name: "牛乳", reason: "reason", confidence: "very-high" },
        { name: "卵", confidence: "high" },
        null,
        "not an object",
      ],
      recommendedItems: [{ reason: "missing name" }, { name: "パン", reason: "ok" }],
    };

    const result = validateAndPostProcess(raw, noActiveItems);
    expect(result.forgottenItems).toEqual([]);
    expect(result.recommendedItems).toEqual([{ name: "パン", reason: "ok" }]);
  });

  it("handles missing/non-array fields gracefully", () => {
    const result = validateAndPostProcess({}, noActiveItems);
    expect(result.status).toBe("empty");
    expect(result.forgottenItems).toEqual([]);
    expect(result.recommendedItems).toEqual([]);
  });
});
