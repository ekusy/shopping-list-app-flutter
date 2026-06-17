/**
 * グループ解散時のサブコレクション再帰削除 + Storage 孤児画像クリーンアップ。
 *
 * `disbandGroup`（`lib/data/repositories/firestore_group_repository.dart`）は
 * グループ文書本体のみを削除し、`items` / `tags` / `itemHistory` /
 * `purchaseHistorySummaries` / 旧 `lists`（および各 nested サブコレクション）は
 * 孤児化する。特に `purchaseHistorySummaries` は TTL 対象外のため永久に残存する。
 *
 * `recursiveDelete` はドキュメント配下のサブコレクションを自動列挙して削除する
 * ため、コレクション名をハードコードする必要がない（将来サブコレクションが
 * 追加されても追従する）。
 *
 * このトリガーが発火する時点でグループ文書自体は既に削除済みのため、
 * `recursiveDelete` 呼び出し自体は no-op（対象パスにドキュメント本体は存在しない）
 * だが、配下のサブコレクションは親文書の存在に関わらず独立して存在するため、
 * それらは削除対象になる。
 *
 * 大きめのグループ（アイテム数・履歴件数が多い）に備え、デフォルトより長い
 * `timeoutSeconds` / 大きい `memory` を指定する。
 */
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { recursiveDeleteGroup } from "../data/history_store";
import { deleteGroupImages } from "../data/storage_store";

export const onGroupDeleted = onDocumentDeleted(
  {
    document: "groups/{groupId}",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (event) => {
    const { groupId } = event.params;

    // Firestore サブコレクションの再帰削除
    try {
      await recursiveDeleteGroup(groupId);
      logger.info("recursively deleted group subcollections", { groupId });
    } catch (error) {
      logger.error("failed to recursively delete group subcollections", {
        groupId,
        error,
      });
      throw error;
    }

    // Storage 孤児画像の一括削除（best-effort: Firestore 削除の成否に関わらず実行）
    try {
      await deleteGroupImages(groupId);
      logger.info("deleted group images from Storage", { groupId });
    } catch (error) {
      logger.warn("failed to delete group images from Storage (best-effort)", {
        groupId,
        error,
      });
      // best-effort: Storage 削除の失敗はトリガー全体をリトライさせない
    }
  },
);
