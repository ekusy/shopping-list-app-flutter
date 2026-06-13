/**
 * Pure business logic for purchase/deletion history capture.
 *
 * Spec: docs/ドラフト/AI提案機能/01-履歴データ設計.md §1〜2
 *
 * This module has no dependency on `firebase-functions` / `firebase-admin`.
 * All timestamps are represented as `Date` (or epoch milliseconds) here;
 * the trigger wrapper (`src/index.ts`) is responsible for converting to/from
 * `firebase-admin` `Timestamp`.
 */

/** Retention period for raw `itemHistory` events (Firestore TTL target). */
export const ITEM_HISTORY_RETENTION_DAYS = 180;

/** Cooldown window for de-duplicating repeated `purchased` events. */
export const PURCHASE_COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

export type ItemHistoryEventType = "purchased" | "deleted";

/**
 * Snapshot of the fields on `groups/{groupId}/items/{itemId}` that are
 * relevant to history capture. Mirrors `lib/data/repositories/firestore_item_repository.dart`.
 */
export interface ItemSnapshotFields {
  name: string;
  tagId?: string;
  /** New field (status-based). */
  status?: string;
  /** New field set when a member declares intent to buy. */
  buyingBy?: string;
  /** Legacy field, kept for backward compatibility (see 01 §7). */
  buyerId?: string;
  addedBy?: string;
  /** Item creation time in epoch milliseconds. */
  createdAtMs?: number;
}

/** Raw event payload for `groups/{groupId}/itemHistory/{eventId}`. */
export interface ItemHistoryEvent {
  type: ItemHistoryEventType;
  itemId: string;
  name: string;
  nameKey: string;
  tagId?: string;
  /** Only present for `deleted` events. */
  statusAtDeletion?: string;
  /** Only present for `purchased` events. */
  purchasedBy?: string;
  addedBy?: string;
  /** Epoch milliseconds. */
  itemCreatedAtMs?: number;
  /** Epoch milliseconds. */
  occurredAtMs: number;
  /** Epoch milliseconds. */
  expiresAtMs: number;
}

/** `groups/{groupId}/purchaseHistorySummaries/{nameKey}` document shape. */
export interface PurchaseHistorySummary {
  name: string;
  purchaseCount: number;
  deletedWithoutPurchaseCount: number;
  /** Epoch milliseconds. */
  firstPurchasedAt?: number;
  /** Epoch milliseconds. */
  lastPurchasedAt?: number;
  totalCycleDays: number;
  lastTagId?: string;
  /** Epoch milliseconds. */
  updatedAt: number;
}

/**
 * Returns true iff the item-document update represents a transition from
 * `active` to `purchased` (the only update that should be recorded as a
 * `purchased` event). All other updates (including the reverse transition
 * `purchased` -> `active`) are ignored.
 */
export function isPurchaseTransition(
  beforeStatus: string | undefined,
  afterStatus: string | undefined,
): boolean {
  return beforeStatus === "active" && afterStatus === "purchased";
}

/** `occurredAt + days` expressed in epoch milliseconds. */
export function computeExpiresAt(occurredAtMs: number, days: number): number {
  return occurredAtMs + days * 24 * 60 * 60 * 1000;
}

/**
 * Returns true iff `now` is within `cooldownMs` of `lastOccurredAtMs`
 * (i.e. a new `purchased` event should be skipped as toggle noise).
 *
 * `lastOccurredAtMs` of `undefined` (no prior event) is never within the
 * cooldown.
 */
export function isWithinCooldown(
  lastOccurredAtMs: number | undefined,
  nowMs: number,
  cooldownMs: number,
): boolean {
  if (lastOccurredAtMs === undefined) return false;
  return nowMs - lastOccurredAtMs < cooldownMs;
}

/**
 * Build the `itemHistory` payload for a `purchased` event.
 *
 * `purchasedBy` is `buyingBy ?? buyerId` per 01 §2.1.
 */
export function buildPurchasedEvent(params: {
  itemId: string;
  item: ItemSnapshotFields;
  nameKey: string;
  occurredAtMs: number;
}): ItemHistoryEvent {
  const { itemId, item, nameKey, occurredAtMs } = params;
  // `buyingBy` (intent-to-buy declarer) wins over the legacy `buyerId`; fall
  // back to `buyerId` only when `buyingBy` is absent (01 §2.1). Computed once
  // so the precedence of `??` vs the surrounding spread stays unambiguous.
  const purchasedBy = item.buyingBy ?? item.buyerId;
  return {
    type: "purchased",
    itemId,
    name: item.name,
    nameKey,
    ...(item.tagId !== undefined ? { tagId: item.tagId } : {}),
    ...(purchasedBy ? { purchasedBy } : {}),
    ...(item.addedBy !== undefined ? { addedBy: item.addedBy } : {}),
    ...(item.createdAtMs !== undefined
      ? { itemCreatedAtMs: item.createdAtMs }
      : {}),
    occurredAtMs,
    expiresAtMs: computeExpiresAt(occurredAtMs, ITEM_HISTORY_RETENTION_DAYS),
  };
}

/**
 * Build the `itemHistory` payload for a `deleted` event.
 *
 * `statusAtDeletion` is the `status` field of the item document at the time
 * of deletion (used to distinguish "purchased then cleaned up" from
 * "removed without ever being purchased").
 */
export function buildDeletedEvent(params: {
  itemId: string;
  item: ItemSnapshotFields;
  nameKey: string;
  occurredAtMs: number;
}): ItemHistoryEvent {
  const { itemId, item, nameKey, occurredAtMs } = params;
  return {
    type: "deleted",
    itemId,
    name: item.name,
    nameKey,
    ...(item.tagId !== undefined ? { tagId: item.tagId } : {}),
    ...(item.status !== undefined ? { statusAtDeletion: item.status } : {}),
    ...(item.addedBy !== undefined ? { addedBy: item.addedBy } : {}),
    ...(item.createdAtMs !== undefined
      ? { itemCreatedAtMs: item.createdAtMs }
      : {}),
    occurredAtMs,
    expiresAtMs: computeExpiresAt(occurredAtMs, ITEM_HISTORY_RETENTION_DAYS),
  };
}

/**
 * Apply a `purchased` event to the current summary (or create a new one if
 * `current` is undefined).
 *
 * - `purchaseCount` is incremented.
 * - `firstPurchasedAt` is set only if not already present.
 * - `totalCycleDays` accumulates the gap (in days) between this event's
 *   `occurredAt` and the previous `lastPurchasedAt`, only when a previous
 *   value exists (i.e. not on the first purchase). The gap is clamped to a
 *   non-negative value: Firestore triggers are at-least-once and not strictly
 *   ordered (01 §7), so an out-of-order / redelivered event whose `occurredAt`
 *   predates the stored `lastPurchasedAt` would otherwise contribute a
 *   negative delta and corrupt the derived `avgCycleDays`.
 * - `lastPurchasedAt`, `name`, `lastTagId`, `updatedAt` are refreshed to the
 *   event's values.
 */
export function applyPurchaseToSummary(
  current: PurchaseHistorySummary | undefined,
  event: ItemHistoryEvent,
): PurchaseHistorySummary {
  const base: PurchaseHistorySummary = current ?? {
    name: event.name,
    purchaseCount: 0,
    deletedWithoutPurchaseCount: 0,
    totalCycleDays: 0,
    updatedAt: event.occurredAtMs,
  };

  const previousLastPurchasedAt = base.lastPurchasedAt;
  const cycleDaysToAdd =
    previousLastPurchasedAt !== undefined
      ? Math.max(
          0,
          (event.occurredAtMs - previousLastPurchasedAt) /
            (24 * 60 * 60 * 1000),
        )
      : 0;

  return {
    ...base,
    name: event.name,
    purchaseCount: base.purchaseCount + 1,
    firstPurchasedAt: base.firstPurchasedAt ?? event.occurredAtMs,
    lastPurchasedAt: event.occurredAtMs,
    totalCycleDays: base.totalCycleDays + cycleDaysToAdd,
    lastTagId: event.tagId ?? base.lastTagId,
    updatedAt: event.occurredAtMs,
  };
}

/**
 * Apply a `deleted` event to the current summary (or create a new one if
 * `current` is undefined).
 *
 * Only `statusAtDeletion === 'active'` deletions affect the summary
 * (`deletedWithoutPurchaseCount` is incremented). Deletions of items that
 * were `purchased` (post-purchase cleanup) leave the summary's purchase
 * fields untouched — the purchase was already recorded by the status
 * transition event — but `updatedAt` is still refreshed so the summary
 * reflects recent group activity.
 */
export function applyDeletionToSummary(
  current: PurchaseHistorySummary | undefined,
  event: ItemHistoryEvent,
): PurchaseHistorySummary {
  const base: PurchaseHistorySummary = current ?? {
    name: event.name,
    purchaseCount: 0,
    deletedWithoutPurchaseCount: 0,
    totalCycleDays: 0,
    updatedAt: event.occurredAtMs,
  };

  if (event.statusAtDeletion !== "active") {
    return {
      ...base,
      updatedAt: event.occurredAtMs,
    };
  }

  return {
    ...base,
    name: event.name,
    deletedWithoutPurchaseCount: base.deletedWithoutPurchaseCount + 1,
    lastTagId: event.tagId ?? base.lastTagId,
    updatedAt: event.occurredAtMs,
  };
}
