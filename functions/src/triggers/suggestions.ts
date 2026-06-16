/**
 * Weekly AI suggestion pipeline — `onSchedule` wrapper (Issue #40 Phase 1).
 *
 * Design principle (Issue #37 Phase 0 — keep this for all future triggers):
 *   - Trigger wrappers (this file) should stay THIN: they only handle
 *     framework concerns (schedule event, logging) and delegate all business
 *     logic to pure functions under `src/lib/`.
 *   - Logic under `src/lib/` must not import `firebase-functions` /
 *     `firebase-admin` / `@google/genai`, so it stays portable and can be
 *     ported to a Dart Cloud Functions runtime once that becomes GA, with
 *     minimal rewrites confined to the trigger wrapper / data layers.
 *
 * `processGroup` is exported as an independent function so a future move to
 * Cloud Tasks (per-group dispatch, 02 §7) only needs to change how it is
 * invoked, not its implementation.
 *
 * Spec: docs/ドラフト/AI提案機能/02-週次提案パイプライン設計.md
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import {
  buildUserPrompt,
  formatJstTodayLabel,
  isoWeekIdJst,
  shouldSkipGroup,
  SYSTEM_INSTRUCTION,
  validateAndPostProcess,
} from "../lib/suggestions";
import { nameKeyOf } from "../lib/name_key";
import { generateSuggestions, MODEL_ID } from "../data/gemini_client";
import {
  fetchGroupSuggestionInput,
  isSuggestionsEnabled,
  listAllGroupIds,
  saveSuggestion,
} from "../data/suggestions_store";

/** Outcome of processing a single group, used for the end-of-run summary log. */
export type ProcessGroupResult = "generated" | "skipped";

/**
 * Process the weekly suggestion pipeline for a single group:
 *
 * 1. Fetch active items / recent history / summaries.
 * 2. Skip (no Gemini call) if `shouldSkipGroup` is true.
 * 3. Build the prompt and call Gemini (structured output).
 * 4. Validate/post-process the response (exclude already-active items, cap
 *    counts/lengths).
 * 5. Save `suggestions/{weekId}` (idempotent overwrite).
 *
 * Throws on unrecoverable errors (e.g. Gemini call failure after retry) so
 * the caller can catch and log per-group without stopping the whole run.
 */
export async function processGroup(
  groupId: string,
  nowMs: number,
): Promise<ProcessGroupResult> {
  const input = await fetchGroupSuggestionInput(groupId, nowMs);

  if (shouldSkipGroup(input)) {
    return "skipped";
  }

  // The schedule fires at 08:00 JST (= 23:00 UTC the previous day). All
  // calendar derivations below (today's label, the week id) must use the JST
  // wall-clock, not UTC, or they would reference the wrong date/week.
  const todayLabel = formatJstTodayLabel(nowMs);

  const userPrompt = buildUserPrompt({
    todayLabel,
    activeItems: input.activeItems,
    summaries: input.summaries,
    historyEvents: input.historyEvents,
  });

  const raw = await generateSuggestions(SYSTEM_INSTRUCTION, userPrompt);

  const activeNameKeys = new Set(
    input.activeItems.map((item) => nameKeyOf(item.name)),
  );
  const result = validateAndPostProcess(raw, activeNameKeys);

  const weekId = isoWeekIdJst(nowMs);
  await saveSuggestion(groupId, weekId, {
    generatedAtMs: nowMs,
    model: MODEL_ID,
    result,
    inputStats: {
      activeItems: input.activeItems.length,
      historyEvents: input.historyEvents.length,
      summaries: input.summaries.length,
    },
  });

  return "generated";
}

export const weeklySuggestions = onSchedule(
  {
    schedule: "every saturday 08:00",
    timeZone: "Asia/Tokyo",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    if (!(await isSuggestionsEnabled())) {
      logger.info("weeklySuggestions: suggestionsEnabled is false, exiting");
      return;
    }

    const groupIds = await listAllGroupIds();
    const nowMs = Date.now();

    let generated = 0;
    let skipped = 0;
    let failed = 0;

    for (const groupId of groupIds) {
      try {
        const outcome = await processGroup(groupId, nowMs);
        if (outcome === "generated") {
          generated++;
        } else {
          skipped++;
        }
      } catch (error) {
        failed++;
        logger.error("weeklySuggestions: failed to process group", {
          groupId,
          error,
        });
      }
    }

    logger.info("weeklySuggestions: run summary", {
      totalGroups: groupIds.length,
      generated,
      skipped,
      failed,
    });
  },
);
