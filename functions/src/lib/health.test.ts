import { describe, expect, it } from "vitest";
import { healthPayload } from "./health";

describe("healthPayload", () => {
  it("returns an ok status with the service name", () => {
    expect(healthPayload()).toEqual({
      status: "ok",
      service: "shopping-list-app-functions",
    });
  });
});
