import { describe, expect, it } from "vitest";
import {
  applyDeletionToSummary,
  applyPurchaseToSummary,
  buildDeletedEvent,
  buildPurchasedEvent,
  computeExpiresAt,
  ITEM_HISTORY_RETENTION_DAYS,
  isPurchaseTransition,
  isWithinCooldown,
  PURCHASE_COOLDOWN_MS,
  type ItemHistoryEvent,
  type PurchaseHistorySummary,
} from "./history";

const DAY_MS = 24 * 60 * 60 * 1000;

describe("isPurchaseTransition", () => {
  it("is true only for active -> purchased", () => {
    expect(isPurchaseTransition("active", "purchased")).toBe(true);
  });

  it("is false for the reverse transition (toggle back)", () => {
    expect(isPurchaseTransition("purchased", "active")).toBe(false);
  });

  it("is false for no-op or unrelated updates", () => {
    expect(isPurchaseTransition("active", "active")).toBe(false);
    expect(isPurchaseTransition("purchased", "purchased")).toBe(false);
    expect(isPurchaseTransition(undefined, "purchased")).toBe(false);
  });
});

describe("computeExpiresAt", () => {
  it("adds the given number of days in milliseconds", () => {
    const occurredAt = 1_000_000;
    expect(computeExpiresAt(occurredAt, 180)).toBe(occurredAt + 180 * DAY_MS);
  });

  it("uses the 180-day retention constant for itemHistory", () => {
    expect(ITEM_HISTORY_RETENTION_DAYS).toBe(180);
  });
});

describe("isWithinCooldown", () => {
  const now = 10_000_000;

  it("is false when there is no prior event", () => {
    expect(isWithinCooldown(undefined, now, PURCHASE_COOLDOWN_MS)).toBe(
      false,
    );
  });

  it("is true when the prior event is within the cooldown window", () => {
    const last = now - (PURCHASE_COOLDOWN_MS - 1);
    expect(isWithinCooldown(last, now, PURCHASE_COOLDOWN_MS)).toBe(true);
  });

  it("is false when the prior event is exactly at or beyond the cooldown window", () => {
    const last = now - PURCHASE_COOLDOWN_MS;
    expect(isWithinCooldown(last, now, PURCHASE_COOLDOWN_MS)).toBe(false);

    const longAgo = now - (PURCHASE_COOLDOWN_MS + 1);
    expect(isWithinCooldown(longAgo, now, PURCHASE_COOLDOWN_MS)).toBe(false);
  });

  it("the default cooldown is one hour", () => {
    expect(PURCHASE_COOLDOWN_MS).toBe(60 * 60 * 1000);
  });
});

describe("buildPurchasedEvent", () => {
  const occurredAtMs = 1_700_000_000_000;

  it("prefers buyingBy over buyerId for purchasedBy", () => {
    const event = buildPurchasedEvent({
      itemId: "item-1",
      item: { name: "牛乳", buyingBy: "uid-new", buyerId: "uid-old" },
      nameKey: "key-1",
      occurredAtMs,
    });
    expect(event.purchasedBy).toBe("uid-new");
  });

  it("falls back to buyerId when buyingBy is absent", () => {
    const event = buildPurchasedEvent({
      itemId: "item-1",
      item: { name: "牛乳", buyerId: "uid-old" },
      nameKey: "key-1",
      occurredAtMs,
    });
    expect(event.purchasedBy).toBe("uid-old");
  });

  it("omits purchasedBy when neither field is present", () => {
    const event = buildPurchasedEvent({
      itemId: "item-1",
      item: { name: "牛乳" },
      nameKey: "key-1",
      occurredAtMs,
    });
    expect(event.purchasedBy).toBeUndefined();
  });

  it("sets type, occurredAt and expiresAt (180 days later)", () => {
    const event = buildPurchasedEvent({
      itemId: "item-1",
      item: { name: "牛乳", tagId: "tag-1", addedBy: "uid-a", createdAtMs: 1 },
      nameKey: "key-1",
      occurredAtMs,
    });
    expect(event.type).toBe("purchased");
    expect(event.occurredAtMs).toBe(occurredAtMs);
    expect(event.expiresAtMs).toBe(occurredAtMs + 180 * DAY_MS);
    expect(event.tagId).toBe("tag-1");
    expect(event.addedBy).toBe("uid-a");
    expect(event.itemCreatedAtMs).toBe(1);
  });

  it("does not include statusAtDeletion", () => {
    const event = buildPurchasedEvent({
      itemId: "item-1",
      item: { name: "牛乳", status: "purchased" },
      nameKey: "key-1",
      occurredAtMs,
    });
    expect(event.statusAtDeletion).toBeUndefined();
  });
});

describe("buildDeletedEvent", () => {
  const occurredAtMs = 1_700_000_000_000;

  it("records statusAtDeletion from the item snapshot", () => {
    const event = buildDeletedEvent({
      itemId: "item-1",
      item: { name: "牛乳", status: "active" },
      nameKey: "key-1",
      occurredAtMs,
    });
    expect(event.type).toBe("deleted");
    expect(event.statusAtDeletion).toBe("active");
    expect(event.expiresAtMs).toBe(occurredAtMs + 180 * DAY_MS);
  });

  it("does not include purchasedBy", () => {
    const event = buildDeletedEvent({
      itemId: "item-1",
      item: { name: "牛乳", status: "purchased", buyingBy: "uid-1" },
      nameKey: "key-1",
      occurredAtMs,
    });
    expect(event.purchasedBy).toBeUndefined();
  });
});

describe("applyPurchaseToSummary", () => {
  const nameKey = "key-1";

  function purchasedEvent(
    occurredAtMs: number,
    overrides: Partial<ItemHistoryEvent> = {},
  ): ItemHistoryEvent {
    return {
      type: "purchased",
      itemId: "item-1",
      name: "牛乳",
      nameKey,
      occurredAtMs,
      expiresAtMs: computeExpiresAt(occurredAtMs, 180),
      ...overrides,
    };
  }

  it("first purchase: sets firstPurchasedAt and lastPurchasedAt, no cycle days", () => {
    const event = purchasedEvent(1_000 * DAY_MS);
    const summary = applyPurchaseToSummary(undefined, event);

    expect(summary.purchaseCount).toBe(1);
    expect(summary.firstPurchasedAt).toBe(event.occurredAtMs);
    expect(summary.lastPurchasedAt).toBe(event.occurredAtMs);
    expect(summary.totalCycleDays).toBe(0);
    expect(summary.name).toBe("牛乳");
  });

  it("second purchase: accumulates cycle days since the previous purchase", () => {
    const first = purchasedEvent(1_000 * DAY_MS);
    const afterFirst = applyPurchaseToSummary(undefined, first);

    const second = purchasedEvent(1_007 * DAY_MS); // 7 days later
    const afterSecond = applyPurchaseToSummary(afterFirst, second);

    expect(afterSecond.purchaseCount).toBe(2);
    expect(afterSecond.firstPurchasedAt).toBe(first.occurredAtMs);
    expect(afterSecond.lastPurchasedAt).toBe(second.occurredAtMs);
    expect(afterSecond.totalCycleDays).toBeCloseTo(7, 6);
  });

  it("third purchase: accumulates additional cycle days on top of existing total", () => {
    let summary: PurchaseHistorySummary | undefined = undefined;
    summary = applyPurchaseToSummary(summary, purchasedEvent(1_000 * DAY_MS));
    summary = applyPurchaseToSummary(summary, purchasedEvent(1_007 * DAY_MS));
    summary = applyPurchaseToSummary(summary, purchasedEvent(1_010 * DAY_MS)); // +3 days

    expect(summary.purchaseCount).toBe(3);
    expect(summary.totalCycleDays).toBeCloseTo(10, 6);
  });

  it("clamps the cycle delta to 0 for an out-of-order (earlier) event", () => {
    // Firestore triggers are at-least-once and not strictly ordered (01 §7):
    // a redelivered/out-of-order event whose occurredAt predates the stored
    // lastPurchasedAt must not push totalCycleDays negative.
    const first = purchasedEvent(1_000 * DAY_MS);
    const afterFirst = applyPurchaseToSummary(undefined, first);

    const earlier = purchasedEvent(990 * DAY_MS); // 10 days BEFORE the first
    const afterEarlier = applyPurchaseToSummary(afterFirst, earlier);

    expect(afterEarlier.purchaseCount).toBe(2);
    expect(afterEarlier.totalCycleDays).toBe(0); // not -10
    expect(afterEarlier.totalCycleDays).toBeGreaterThanOrEqual(0);
  });

  it("updates name and lastTagId to the latest event values", () => {
    const first = purchasedEvent(1_000 * DAY_MS, {
      name: "旧名称",
      tagId: "tag-old",
    });
    const afterFirst = applyPurchaseToSummary(undefined, first);

    const second = purchasedEvent(1_007 * DAY_MS, {
      name: "新名称",
      tagId: "tag-new",
    });
    const afterSecond = applyPurchaseToSummary(afterFirst, second);

    expect(afterSecond.name).toBe("新名称");
    expect(afterSecond.lastTagId).toBe("tag-new");
  });

  it("keeps the previous lastTagId when the new event has no tagId", () => {
    const first = purchasedEvent(1_000 * DAY_MS, { tagId: "tag-old" });
    const afterFirst = applyPurchaseToSummary(undefined, first);

    const second = purchasedEvent(1_007 * DAY_MS);
    const afterSecond = applyPurchaseToSummary(afterFirst, second);

    expect(afterSecond.lastTagId).toBe("tag-old");
  });
});

describe("applyDeletionToSummary", () => {
  const nameKey = "key-1";

  function deletedEvent(
    occurredAtMs: number,
    overrides: Partial<ItemHistoryEvent> = {},
  ): ItemHistoryEvent {
    return {
      type: "deleted",
      itemId: "item-1",
      name: "牛乳",
      nameKey,
      occurredAtMs,
      expiresAtMs: computeExpiresAt(occurredAtMs, 180),
      ...overrides,
    };
  }

  it("active deletion increments deletedWithoutPurchaseCount", () => {
    const event = deletedEvent(1_000 * DAY_MS, { statusAtDeletion: "active" });
    const summary = applyDeletionToSummary(undefined, event);

    expect(summary.deletedWithoutPurchaseCount).toBe(1);
    expect(summary.purchaseCount).toBe(0);
  });

  it("purchased deletion (post-purchase cleanup) leaves purchase fields untouched", () => {
    const purchaseEvent: ItemHistoryEvent = {
      type: "purchased",
      itemId: "item-1",
      name: "牛乳",
      nameKey,
      occurredAtMs: 1_000 * DAY_MS,
      expiresAtMs: computeExpiresAt(1_000 * DAY_MS, 180),
    };
    const afterPurchase = applyPurchaseToSummary(undefined, purchaseEvent);

    const event = deletedEvent(1_001 * DAY_MS, {
      statusAtDeletion: "purchased",
    });
    const afterDeletion = applyDeletionToSummary(afterPurchase, event);

    expect(afterDeletion.purchaseCount).toBe(afterPurchase.purchaseCount);
    expect(afterDeletion.firstPurchasedAt).toBe(afterPurchase.firstPurchasedAt);
    expect(afterDeletion.lastPurchasedAt).toBe(afterPurchase.lastPurchasedAt);
    expect(afterDeletion.totalCycleDays).toBe(afterPurchase.totalCycleDays);
    expect(afterDeletion.deletedWithoutPurchaseCount).toBe(0);
    // updatedAt still refreshes to reflect recent activity.
    expect(afterDeletion.updatedAt).toBe(event.occurredAtMs);
  });

  it("active deletion on a fresh summary sets name and lastTagId", () => {
    const event = deletedEvent(1_000 * DAY_MS, {
      statusAtDeletion: "active",
      tagId: "tag-1",
    });
    const summary = applyDeletionToSummary(undefined, event);

    expect(summary.name).toBe("牛乳");
    expect(summary.lastTagId).toBe("tag-1");
  });

  it("deletion with no statusAtDeletion only refreshes updatedAt", () => {
    // An item deleted without a `status` field (statusAtDeletion undefined)
    // is neither a purchase nor a "deleted-without-purchase" signal: it must
    // not increment either counter, only refresh updatedAt.
    const event = deletedEvent(1_000 * DAY_MS); // no statusAtDeletion
    const summary = applyDeletionToSummary(undefined, event);

    expect(summary.deletedWithoutPurchaseCount).toBe(0);
    expect(summary.purchaseCount).toBe(0);
    expect(summary.updatedAt).toBe(event.occurredAtMs);
  });
});
