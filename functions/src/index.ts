/**
 * Cloud Functions entry point.
 *
 * Design principle (Issue #37 Phase 0 — keep this for all future triggers):
 *   - Trigger wrappers (this file) should stay THIN: they only handle
 *     framework concerns (HTTP request/response, Firestore event shape,
 *     logging) and delegate all business logic to pure functions under
 *     `src/lib/`.
 *   - Logic under `src/lib/` must not import `firebase-functions`, so it
 *     stays portable and can be ported to a Dart Cloud Functions runtime
 *     once that becomes GA, with minimal rewrites confined to the trigger
 *     wrapper layer.
 */
import { setGlobalOptions } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";
import {
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { healthPayload } from "./lib/health";
import {
  applyDeletionToSummary,
  applyPurchaseToSummary,
  buildDeletedEvent,
  buildPurchasedEvent,
  isPurchaseTransition,
  isWithinCooldown,
  PURCHASE_COOLDOWN_MS,
  type ItemHistoryEvent,
  type ItemSnapshotFields,
  type PurchaseHistorySummary,
} from "./lib/history";
import { nameKeyOf } from "./lib/name_key";

// すべての関数の既定値を集約設定する。
// - region: 全関数を asia-northeast1 に固定。
// - maxInstances: 公開エンドポイント（health の onRequest 等）が誤って呼ばれ続けた
//   場合でも青天井にスケールしないよう、暴走・コスト保険として小さめの上限を置く。
//   本番トラフィックを捌く関数を追加する際は、関数ごとに onRequest({ maxInstances }) で
//   個別に引き上げること。
setGlobalOptions({ region: "asia-northeast1", maxInstances: 10 });

initializeApp();

export const health = onRequest((_request, response) => {
  const payload = healthPayload();
  logger.info("health check requested", { payload });
  response.json(payload);
});

/**
 * Convert a Firestore item document's raw fields into the
 * `ItemSnapshotFields` shape consumed by `src/lib/history.ts`.
 *
 * Mirrors the field names written by
 * `lib/data/repositories/firestore_item_repository.dart`
 * (name/category/note/imageUrl/createdAt/order/status/buyingBy/addedBy/tagId,
 * plus legacy buyerId).
 */
function toItemSnapshotFields(
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
function toItemHistoryDoc(
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
function toSummaryDoc(
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
function fromSummaryDoc(
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
async function recordEventAndUpdateSummary(
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
 * `purchased` イベントの記録: `status` が `active` -> `purchased` に遷移した
 * 場合のみ処理する。トグルノイズ対策として、直近 1 時間以内に同一アイテムの
 * `purchased` イベントが既に記録されていればスキップする。
 *
 * Spec: docs/ドラフト/AI提案機能/01-履歴データ設計.md §1.2, §2
 */
export const onItemUpdated = onDocumentUpdated(
  "groups/{groupId}/items/{itemId}",
  async (event) => {
    const { groupId, itemId } = event.params;
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    const beforeStatus =
      typeof before?.status === "string" ? before.status : undefined;
    const afterStatus =
      typeof after?.status === "string" ? after.status : undefined;

    if (!isPurchaseTransition(beforeStatus, afterStatus)) {
      return;
    }

    const item = toItemSnapshotFields(after);
    const nameKey = nameKeyOf(item.name);
    const occurredAtMs = event.time ? Date.parse(event.time) : Date.now();

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

    if (!recentSnap.empty) {
      const lastOccurredAt = recentSnap.docs[0].data().occurredAt;
      const lastOccurredAtMs =
        lastOccurredAt instanceof Timestamp
          ? lastOccurredAt.toMillis()
          : undefined;
      if (isWithinCooldown(lastOccurredAtMs, occurredAtMs, PURCHASE_COOLDOWN_MS)) {
        logger.info("skip purchased event: within cooldown", {
          groupId,
          itemId,
        });
        return;
      }
    }

    const purchasedEvent = buildPurchasedEvent({
      itemId,
      item,
      nameKey,
      occurredAtMs,
    });

    await recordEventAndUpdateSummary(
      groupId,
      purchasedEvent,
      applyPurchaseToSummary,
    );
  },
);

/**
 * `deleted` イベントの記録: アイテムドキュメント削除時に削除時点の全フィールドの
 * スナップショットから `deleted` イベントを記録し、`statusAtDeletion === 'active'`
 * の場合のみサマリーの `deletedWithoutPurchaseCount` を更新する。
 *
 * Spec: docs/ドラフト/AI提案機能/01-履歴データ設計.md §1.2, §2
 */
export const onItemDeleted = onDocumentDeleted(
  "groups/{groupId}/items/{itemId}",
  async (event) => {
    const { groupId, itemId } = event.params;
    const deleted = event.data?.data();

    const item = toItemSnapshotFields(deleted);
    const nameKey = nameKeyOf(item.name);
    const occurredAtMs = event.time ? Date.parse(event.time) : Date.now();

    const deletedEvent = buildDeletedEvent({
      itemId,
      item,
      nameKey,
      occurredAtMs,
    });

    await recordEventAndUpdateSummary(
      groupId,
      deletedEvent,
      applyDeletionToSummary,
    );
  },
);
