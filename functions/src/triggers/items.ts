/**
 * Item document triggers — purchase/deletion history capture.
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
import {
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import {
  applyDeletionToSummary,
  applyPurchaseToSummary,
  buildDeletedEvent,
  buildPurchasedEvent,
  isPurchaseTransition,
  isWithinCooldown,
  PURCHASE_COOLDOWN_MS,
} from "../lib/history";
import { nameKeyOf } from "../lib/name_key";
import {
  findRecentPurchasedOccurredAtMs,
  groupExists,
  recordEventAndUpdateSummary,
  toItemSnapshotFields,
} from "../data/history_store";
import { deleteItemImage } from "../data/storage_store";

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

    const lastOccurredAtMs = await findRecentPurchasedOccurredAtMs(
      groupId,
      itemId,
    );
    if (isWithinCooldown(lastOccurredAtMs, occurredAtMs, PURCHASE_COOLDOWN_MS)) {
      logger.info("skip purchased event: within cooldown", {
        groupId,
        itemId,
      });
      return;
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
 * `deleted` イベントの記録 + Storage 孤児画像クリーンアップ。
 *
 * アイテムドキュメント削除時に:
 *   1. 削除時点のスナップショットから `deleted` イベントを記録する。
 *   2. Storage のアイテム画像を best-effort で削除する（画像なしアイテムは no-op）。
 *
 * グループ解散中（`onGroupDeleted` の recursiveDelete に起因する at-least-once 発火）の
 * 場合は履歴記録をスキップするが、Storage 削除は独立して実行する。
 * グループ画像は `onGroupDeleted` 側で `deleteGroupImages` によって一括削除される。
 *
 * Spec: docs/ドラフト/AI提案機能/01-履歴データ設計.md §1.2, §2
 */
export const onItemDeleted = onDocumentDeleted(
  "groups/{groupId}/items/{itemId}",
  async (event) => {
    const { groupId, itemId } = event.params;
    const deleted = event.data?.data();

    // Storage の孤児画像クリーンアップ（best-effort: グループ解散ガードとは独立）
    // `deleteItemImage` 内部で not-found を無視するため、画像なしアイテムも安全。
    try {
      await deleteItemImage(groupId, itemId);
    } catch (error) {
      // best-effort: 失敗しても履歴記録は続ける
      logger.warn("failed to delete item image in onItemDeleted", {
        groupId,
        itemId,
        error,
      });
    }

    // グループ解散中のガード（レース対策）:
    // `onGroupDeleted` の recursiveDelete によって `items/{itemId}` が削除された
    // 場合、このトリガーも（at-least-once で）発火する。その時点では親グループ
    // 文書 `groups/{groupId}` は既に削除済みのため、ここでイベント記録を
    // スキップする。スキップしない場合、recursiveDelete が既にスキャン済みの
    // `itemHistory` / `purchaseHistorySummaries` に新たな `deleted` イベントや
    // サマリーが書き戻され、TTL 対象外の summaries が永久に孤児化してしまう。
    //
    // 通常の単品削除・購入済み一括削除・タグ連動削除では親グループ文書が存在する
    // ため、この分岐には入らず従来どおり記録される。
    if (!(await groupExists(groupId))) {
      logger.info("skip deleted event: group is being disbanded", {
        groupId,
        itemId,
      });
      return;
    }

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
