/**
 * Firestore I/O for purchase/deletion history capture and group teardown.
 *
 * This module wraps `firebase-admin/firestore` access on behalf of
 * `src/triggers/items.ts` and `src/triggers/groups.ts`. Conversion helpers
 * translate between the pure epoch-ms shapes in `src/lib/history.ts` and
 * Firestore `Timestamp`-bearing documents.
 *
 * Spec: docs/ドラフト/AI提案機能/01-履歴データ設計.md §1〜2
 */
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import {
  type ItemHistoryEvent,
  type ItemSnapshotFields,
  type PurchaseHistorySummary,
} from "../lib/history";

/**
 * Convert a Firestore item document's raw fields into the
 * `ItemSnapshotFields` shape consumed by `src/lib/history.ts`.
 *
 * Mirrors the field names written by
 * `lib/data/repositories/firestore_item_repository.dart`
 * (name/category/note/imageUrl/createdAt/order/status/buyingBy/addedBy/tagId,
 * plus legacy buyerId).
 */
export function toItemSnapshotFields(
  data: Record<string, unknown> | undefined,
): ItemSnapshotFields {
  const createdAt = data?.createdAt;
  return {
    name: typeof data?.name === "string" ? data.name : "",
    tagId: typeof data?.tagId === "string" ? data.tagId : undefined,
    status: typeof data?.status === "string" ? data.status : undefined,
    buyingBy: typeof data?.buyingBy === "string" ? data.buyingBy : undefined,
    buyerId: typeof data?.buyerId === "string" ? data.buyerId : undefined,
    addedBy: typeof data?.addedBy === "string" ? data.addedBy : undefined,
    createdAtMs:
      createdAt instanceof Timestamp ? createdAt.toMillis() : undefined,
  };
}

/** Convert a pure `ItemHistoryEvent` (epoch-ms) into a Firestore document. */
export function toItemHistoryDoc(
  event: ItemHistoryEvent,
): Record<string, unknown> {
  const doc: Record<string, unknown> = {
    type: event.type,
    itemId: event.itemId,
    name: event.name,
    nameKey: event.nameKey,
    occurredAt: Timestamp.fromMillis(event.occurredAtMs),
    expiresAt: Timestamp.fromMillis(event.expiresAtMs),
  };
  if (event.tagId !== undefined) doc.tagId = event.tagId;
  if (event.statusAtDeletion !== undefined) {
    doc.statusAtDeletion = event.statusAtDeletion;
  }
  if (event.purchasedBy !== undefined) doc.purchasedBy = event.purchasedBy;
  if (event.addedBy !== undefined) doc.addedBy = event.addedBy;
  if (event.itemCreatedAtMs !== undefined) {
    doc.itemCreatedAt = Timestamp.fromMillis(event.itemCreatedAtMs);
  }
  return doc;
}

/** Convert a `PurchaseHistorySummary` (epoch-ms) into a Firestore document. */
export function toSummaryDoc(
  summary: PurchaseHistorySummary,
): Record<string, unknown> {
  const doc: Record<string, unknown> = {
    name: summary.name,
    purchaseCount: summary.purchaseCount,
    deletedWithoutPurchaseCount: summary.deletedWithoutPurchaseCount,
    totalCycleDays: summary.totalCycleDays,
    updatedAt: Timestamp.fromMillis(summary.updatedAt),
  };
  if (summary.firstPurchasedAt !== undefined) {
    doc.firstPurchasedAt = Timestamp.fromMillis(summary.firstPurchasedAt);
  }
  if (summary.lastPurchasedAt !== undefined) {
    doc.lastPurchasedAt = Timestamp.fromMillis(summary.lastPurchasedAt);
  }
  if (summary.lastTagId !== undefined) doc.lastTagId = summary.lastTagId;
  return doc;
}

/** Convert a Firestore `purchaseHistorySummaries` document into the pure shape. */
export function fromSummaryDoc(
  data: Record<string, unknown> | undefined,
): PurchaseHistorySummary | undefined {
  if (!data) return undefined;
  const firstPurchasedAt = data.firstPurchasedAt;
  const lastPurchasedAt = data.lastPurchasedAt;
  const updatedAt = data.updatedAt;
  return {
    name: typeof data.name === "string" ? data.name : "",
    purchaseCount:
      typeof data.purchaseCount === "number" ? data.purchaseCount : 0,
    deletedWithoutPurchaseCount:
      typeof data.deletedWithoutPurchaseCount === "number"
        ? data.deletedWithoutPurchaseCount
        : 0,
    firstPurchasedAt:
      firstPurchasedAt instanceof Timestamp
        ? firstPurchasedAt.toMillis()
        : undefined,
    lastPurchasedAt:
      lastPurchasedAt instanceof Timestamp
        ? lastPurchasedAt.toMillis()
        : undefined,
    totalCycleDays:
      typeof data.totalCycleDays === "number" ? data.totalCycleDays : 0,
    lastTagId:
      typeof data.lastTagId === "string" ? data.lastTagId : undefined,
    updatedAt:
      updatedAt instanceof Timestamp ? updatedAt.toMillis() : Date.now(),
  };
}

/**
 * Record an `itemHistory` event and apply it to the corresponding
 * `purchaseHistorySummaries/{nameKey}` document, all within a single
 * transaction (the summary update must be atomic w.r.t. concurrent events
 * for the same product).
 */
export async function recordEventAndUpdateSummary(
  groupId: string,
  event: ItemHistoryEvent,
  applySummary: (
    current: PurchaseHistorySummary | undefined,
    event: ItemHistoryEvent,
  ) => PurchaseHistorySummary,
): Promise<void> {
  const db = getFirestore();
  const historyRef = db
    .collection("groups")
    .doc(groupId)
    .collection("itemHistory")
    .doc();
  const summaryRef = db
    .collection("groups")
    .doc(groupId)
    .collection("purchaseHistorySummaries")
    .doc(event.nameKey);

  await db.runTransaction(async (tx) => {
    const summarySnap = await tx.get(summaryRef);
    const current = fromSummaryDoc(summarySnap.data());
    const next = applySummary(current, event);

    tx.set(historyRef, toItemHistoryDoc(event));
    tx.set(summaryRef, toSummaryDoc(next));
  });
}

/**
 * Fetch the `occurredAt` (epoch milliseconds) of the most recent `purchased`
 * `itemHistory` event for `itemId`, if any. Used to de-duplicate repeated
 * `purchased` transitions within `PURCHASE_COOLDOWN_MS` (toggle noise).
 */
export async function findRecentPurchasedOccurredAtMs(
  groupId: string,
  itemId: string,
): Promise<number | undefined> {
  const db = getFirestore();
  const recentSnap = await db
    .collection("groups")
    .doc(groupId)
    .collection("itemHistory")
    .where("itemId", "==", itemId)
    .where("type", "==", "purchased")
    .orderBy("occurredAt", "desc")
    .limit(1)
    .get();

  if (recentSnap.empty) return undefined;

  const lastOccurredAt = recentSnap.docs[0].data().occurredAt;
  return lastOccurredAt instanceof Timestamp
    ? lastOccurredAt.toMillis()
    : undefined;
}

/** Returns true iff `groups/{groupId}` exists. */
export async function groupExists(groupId: string): Promise<boolean> {
  const groupSnap = await getFirestore()
    .collection("groups")
    .doc(groupId)
    .get();
  return groupSnap.exists;
}

/**
 * Recursively delete `groups/{groupId}` and all of its subcollections
 * (`items` / `tags` / `itemHistory` / `purchaseHistorySummaries` / legacy
 * `lists`, including nested subcollections).
 */
export async function recursiveDeleteGroup(groupId: string): Promise<void> {
  const db = getFirestore();
  await db.recursiveDelete(db.collection("groups").doc(groupId));
}
