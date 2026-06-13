import { describe, expect, it } from "vitest";
import { nameKeyOf, normalizeName } from "./name_key";

describe("normalizeName", () => {
  it("trims leading and trailing whitespace", () => {
    expect(normalizeName("  牛乳  ")).toBe("牛乳");
  });

  it("collapses runs of internal whitespace into a single space", () => {
    expect(normalizeName("カット   トマト")).toBe("カット トマト");
  });

  it("lowercases ASCII letters", () => {
    expect(normalizeName("Milk")).toBe("milk");
  });

  it("applies NFKC normalization (full-width alnum -> half-width)", () => {
    // "Ｍｉｌｋ１" (full-width) -> "Milk1" -> lowercased -> "milk1"
    expect(normalizeName("Ｍｉｌｋ１")).toBe("milk1");
  });

  it("applies NFKC normalization (half-width katakana -> full-width)", () => {
    // half-width "ミルク" -> full-width "ミルク"
    expect(normalizeName("ミルク")).toBe(normalizeName("ミルク"));
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
