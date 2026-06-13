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
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { healthPayload } from "./lib/health";

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
