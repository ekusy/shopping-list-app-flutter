/**
 * Side-effecting initialization shared by all Cloud Functions.
 *
 * This module MUST be imported first (before any trigger module) so that
 * `setGlobalOptions` is evaluated before `onRequest` / `onDocumentUpdated` /
 * `onDocumentDeleted` builders run in `src/triggers/*`. See `src/index.ts`.
 */
import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";

// すべての関数の既定値を集約設定する。
// - region: 全関数を asia-northeast1 に固定。
// - maxInstances: 公開エンドポイント（health の onRequest 等）が誤って呼ばれ続けた
//   場合でも青天井にスケールしないよう、暴走・コスト保険として小さめの上限を置く。
//   本番トラフィックを捌く関数を追加する際は、関数ごとに onRequest({ maxInstances }) で
//   個別に引き上げること。
setGlobalOptions({ region: "asia-northeast1", maxInstances: 10 });

initializeApp();
