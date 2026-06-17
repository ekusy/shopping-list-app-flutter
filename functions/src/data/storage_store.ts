/**
 * Firebase Storage I/O for item image cleanup.
 *
 * This module wraps `firebase-admin/storage` access on behalf of
 * `src/triggers/items.ts` and `src/triggers/groups.ts`.
 *
 * Design: follows the same data-layer isolation pattern as `history_store.ts`
 * (#52 layering — triggers stay thin, I/O is confined here).
 */
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";

/**
 * アイテム画像を Storage から削除する（best-effort）。
 *
 * パス: `groups/{groupId}/items/{itemId}.jpg`
 * ファイルが存在しない場合は静かにスキップする（`404` は無視）。
 */
export async function deleteItemImage(
  groupId: string,
  itemId: string,
): Promise<void> {
  const bucket = getStorage().bucket();
  const file = bucket.file(`groups/${groupId}/items/${itemId}.jpg`);
  try {
    await file.delete();
  } catch (error: unknown) {
    // GCS の not-found は code 404 で来る。他のエラーは warn で続行（best-effort）。
    const code =
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      (error as { code: unknown }).code;
    if (code === 404) {
      // ファイルが存在しない — 正常系（画像なしアイテムの削除など）
      return;
    }
    logger.warn("failed to delete item image (best-effort, continuing)", {
      groupId,
      itemId,
      error,
    });
  }
}

/**
 * グループ配下の全画像を Storage から削除する（best-effort）。
 *
 * プレフィックス: `groups/{groupId}/`
 * `bucket.deleteFiles` は対象ファイルが 0 件でもエラーにならない。
 */
export async function deleteGroupImages(groupId: string): Promise<void> {
  const bucket = getStorage().bucket();
  try {
    await bucket.deleteFiles({ prefix: `groups/${groupId}/` });
  } catch (error) {
    logger.warn("failed to delete group images (best-effort, continuing)", {
      groupId,
      error,
    });
  }
}
