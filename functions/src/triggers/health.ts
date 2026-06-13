/**
 * Health check endpoint — thin wrapper around `src/lib/health.ts`.
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
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { healthPayload } from "../lib/health";

export const health = onRequest((_request, response) => {
  const payload = healthPayload();
  logger.info("health check requested", { payload });
  response.json(payload);
});
