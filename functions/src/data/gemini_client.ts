/**
 * Vertex AI (Gemini) client for the weekly AI suggestion pipeline (Issue #40 Phase 1).
 *
 * This module is the sole place that imports `@google/genai`. Logic under
 * `src/lib/` must remain free of this dependency so it stays portable.
 *
 * Authentication uses Application Default Credentials (the Functions service
 * account must have `roles/aiplatform.user`) — no API key is used.
 *
 * Spec: docs/ドラフト/AI提案機能/02-週次提案パイプライン設計.md §4, §6.
 */
import { GoogleGenAI } from "@google/genai";
import { logger } from "firebase-functions";
import { RESPONSE_SCHEMA, type RawSuggestionsResponse } from "../lib/suggestions";

/**
 * Gemini model ID used for weekly suggestion generation.
 *
 * Single constant so the model can be bumped in one place. Confirmed GA ID
 * (#56): the latest low-cost Flash-tier model (Gemini 2.0 Flash retired
 * 2026-06-01, the 2.5 series retires 2026-10-16).
 */
export const MODEL_ID = "gemini-3.1-flash-lite";

const GENERATION_TEMPERATURE = 0.3;
const MAX_OUTPUT_TOKENS = 1024;

/** Single retry with exponential backoff for transient Gemini call failures. */
const RETRY_DELAY_MS = 1000;

// Gemini 3.x 系は Vertex AI のリージョンエンドポイント（例: asia-northeast1）では
// 提供されず、`global` エンドポイント経由のみのことが多い。asia-northeast1 指定では
// モデル呼び出しが 404 (ApiError) になったため（#40 初回スケジュール実行で実害）、
// `global` を使用する。Functions 自体のリージョンは asia-northeast1 のまま。
function getLocation(): string {
  return "global";
}

function getProjectId(): string | undefined {
  return (
    process.env.GOOGLE_CLOUD_PROJECT ??
    process.env.GCLOUD_PROJECT ??
    process.env.PROJECT_ID
  );
}

let client: GoogleGenAI | undefined;

function getClient(): GoogleGenAI {
  if (!client) {
    client = new GoogleGenAI({
      vertexai: true,
      project: getProjectId(),
      location: getLocation(),
    });
  }
  return client;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Call Gemini with structured output (`responseSchema`) and return the
 * parsed JSON response. Retries once (exponential backoff) on failure;
 * throws if both attempts fail so the caller (`processGroup`) can catch and
 * log per-group.
 */
export async function generateSuggestions(
  systemInstruction: string,
  userPrompt: string,
): Promise<RawSuggestionsResponse> {
  const attempt = async (): Promise<RawSuggestionsResponse> => {
    const response = await getClient().models.generateContent({
      model: MODEL_ID,
      contents: userPrompt,
      config: {
        systemInstruction,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
        temperature: GENERATION_TEMPERATURE,
        maxOutputTokens: MAX_OUTPUT_TOKENS,
      },
    });

    const text = response.text;
    if (!text) {
      throw new Error("Gemini response contained no text");
    }
    return JSON.parse(text) as RawSuggestionsResponse;
  };

  try {
    return await attempt();
  } catch (error) {
    logger.warn("generateSuggestions: first attempt failed, retrying", {
      error,
    });
    await sleep(RETRY_DELAY_MS);
    return await attempt();
  }
}
