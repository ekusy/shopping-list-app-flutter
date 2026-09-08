import { readFileSync } from "fs";
import { resolve } from "path";
import { describe, expect, it } from "vitest";
import { nameKeyOf, normalizeName } from "./name_key";

/**
 * Shared fixture read by BOTH the TypeScript and the Dart test suites (Issue #88),
 * so the two `normalizeName` implementations cannot drift apart:
 *
 *   - TS   : functions/src/lib/name_key.ts   <- this file
 *   - Dart : lib/core/utils/name_key.dart    <- test/core/name_key_test.dart
 *
 * Path is resolved from this file (functions/src/lib) up to the repository root.
 */
const FIXTURE_PATH = resolve(
  __dirname,
  "../../../test/fixtures/name_normalization_cases.json",
);

type NormalizationCase = {
  description: string;
  input: string;
  expected: string;
};

const fixture: { cases: NormalizationCase[] } = JSON.parse(
  readFileSync(FIXTURE_PATH, "utf8"),
);

describe("normalizeName (shared fixture with the Dart implementation)", () => {
  it("loads the shared fixture", () => {
    expect(fixture.cases.length).toBeGreaterThan(0);
  });

  it.each(fixture.cases)("$description", ({ input, expected }) => {
    expect(normalizeName(input)).toBe(expected);
  });
});

describe("nameKeyOf", () => {
  it("produces the same key for equivalent display variants", () => {
    expect(nameKeyOf("  牛乳  ")).toBe(nameKeyOf("牛乳"));
    expect(nameKeyOf("Milk")).toBe(nameKeyOf("milk"));
    expect(nameKeyOf("Ｍｉｌｋ")).toBe(nameKeyOf("milk"));
    expect(nameKeyOf("カット   トマト")).toBe(nameKeyOf("カット トマト"));
  });

  it("produces different keys for different products", () => {
    expect(nameKeyOf("牛乳")).not.toBe(nameKeyOf("豆乳"));
  });

  it("produces a Firestore-document-id-safe key (no '/' characters)", () => {
    const key = nameKeyOf("牛乳/豆乳 100% こだわり");
    expect(key).not.toContain("/");
    expect(key.length).toBeGreaterThan(0);
  });

  it("is deterministic", () => {
    expect(nameKeyOf("にんじん")).toBe(nameKeyOf("にんじん"));
  });
});
