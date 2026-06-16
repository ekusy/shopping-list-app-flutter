/**
 * Firestore I/O for the weekly AI suggestion pipeline (Issue #40 Phase 1).
 *
 * This module wraps `firebase-admin/firestore` access on behalf of
 * `src/triggers/suggestions.ts`. Conversion helpers translate between the
 * pure epoch-ms shapes in `src/lib/suggestions.ts` and Firestore
 * `Timestamp`-bearing documents.
 *
 * Spec: docs/ドラフト/AI提案機能/02-週次提案パイプライン設計.md
 */
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import {
  HISTORY_WEEKS,
  TOP_SUMMARIES_COUNT,
  computeSuggestionsExpiresAt,
  type ActiveItemInput,
  type GroupSuggestionInput,
  type HistoryEventInput,
  type ProcessedSuggestions,
  type SummaryInput,
} from "../lib/suggestions";

/**
 * Whether the weekly suggestion pipeline is enabled (kill switch).
 *
 * Reads `system/config.suggestionsEnabled`. If the `system/config` document
 * does not exist, or the field is not a boolean, the pipeline is treated as
 * **enabled** (`true`) — i.e. the default is "on" unless an operator
 * explicitly sets `suggestionsEnabled: false` to halt it. This matches the
 * kill-switch's intent (an emergency stop that an operator flips on,
 * documented in 04 §4), rather than requiring opt-in provisioning before the
 * feature can ever run.
 */
export async function isSuggestionsEnabled(): Promise<boolean> {
  const snap = await getFirestore().collection("system").doc("config").get();
  const value = snap.data()?.suggestionsEnabled;
  return typeof value === "boolean" ? value : true;
}

/** List the document IDs of all `groups/{groupId}` documents. */
export async function listAllGroupIds(): Promise<string[]> {
  const snap = await getFirestore().collection("groups").select().get();
  return snap.docs.map((doc) => doc.id);
}

/**
 * Fetch and assemble the pure `GroupSuggestionInput` for `groupId`:
 *
 * - Active items: `items` where `status == 'active'`.
 * - History events: `itemHistory` with `occurredAt >=` `HISTORY_WEEKS` weeks
 *   ago.
 * - Summaries: top `TOP_SUMMARIES_COUNT` `purchaseHistorySummaries` by
 *   `purchaseCount` descending.
 *
 * All Firestore `Timestamp` values are converted to epoch milliseconds here
 * so `src/lib/suggestions.ts` stays free of `firebase-admin` types.
 */
export async function fetchGroupSuggestionInput(
  groupId: string,
  nowMs: number,
): Promise<GroupSuggestionInput> {
  const db = getFirestore();
  const groupRef = db.collection("groups").doc(groupId);

  const historyStartMs = nowMs - HISTORY_WEEKS * 7 * 24 * 60 * 60 * 1000;

  const [activeItemsSnap, historySnap, summariesSnap, tagsSnap] =
    await Promise.all([
      groupRef.collection("items").where("status", "==", "active").get(),
      groupRef
        .collection("itemHistory")
        .where("occurredAt", ">=", Timestamp.fromMillis(historyStartMs))
        .get(),
      groupRef
        .collection("purchaseHistorySummaries")
        .orderBy("purchaseCount", "desc")
        .limit(TOP_SUMMARIES_COUNT)
        .get(),
      groupRef.collection("tags").get(),
    ]);

  const tagNameById = new Map<string, string>();
  for (const doc of tagsSnap.docs) {
    const name = doc.data().name;
    if (typeof name === "string") tagNameById.set(doc.id, name);
  }

  const activeItems: ActiveItemInput[] = activeItemsSnap.docs.map((doc) => {
    const data = doc.data();
    const tagId = typeof data.tagId === "string" ? data.tagId : undefined;
    return {
      name: typeof data.name === "string" ? data.name : "",
      tagName: tagId ? tagNameById.get(tagId) : undefined,
    };
  });

  const historyEvents: HistoryEventInput[] = historySnap.docs.map((doc) => {
    const data = doc.data();
    const occurredAt = data.occurredAt;
    return {
      type: data.type === "deleted" ? "deleted" : "purchased",
      name: typeof data.name === "string" ? data.name : "",
      statusAtDeletion:
        typeof data.statusAtDeletion === "string"
          ? data.statusAtDeletion
          : undefined,
      occurredAtMs:
        occurredAt instanceof Timestamp ? occurredAt.toMillis() : nowMs,
    };
  });

  const summaries: SummaryInput[] = summariesSnap.docs.map((doc) => {
    const data = doc.data();
    const lastPurchasedAt = data.lastPurchasedAt;
    return {
      name: typeof data.name === "string" ? data.name : "",
      purchaseCount:
        typeof data.purchaseCount === "number" ? data.purchaseCount : 0,
      lastPurchasedAt:
        lastPurchasedAt instanceof Timestamp
          ? lastPurchasedAt.toMillis()
          : undefined,
      totalCycleDays:
        typeof data.totalCycleDays === "number" ? data.totalCycleDays : 0,
    };
  });

  return { activeItems, historyEvents, summaries, nowMs };
}

/**
 * Persist `groups/{groupId}/suggestions/{weekId}` (overwrite = idempotent
 * re-runs for the same ISO week).
 */
export async function saveSuggestion(
  groupId: string,
  weekId: string,
  doc: {
    generatedAtMs: number;
    model: string;
    result: ProcessedSuggestions;
    inputStats: {
      activeItems: number;
      historyEvents: number;
      summaries: number;
    };
  },
): Promise<void> {
  const db = getFirestore();
  await db
    .collection("groups")
    .doc(groupId)
    .collection("suggestions")
    .doc(weekId)
    .set({
      generatedAt: Timestamp.fromMillis(doc.generatedAtMs),
      model: doc.model,
      status: doc.result.status,
      forgottenItems: doc.result.forgottenItems,
      recommendedItems: doc.result.recommendedItems,
      inputStats: doc.inputStats,
      expiresAt: Timestamp.fromMillis(
        computeSuggestionsExpiresAt(doc.generatedAtMs),
      ),
    });
}
