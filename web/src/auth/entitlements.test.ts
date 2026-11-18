import { describe, expect, it } from "vitest";
import { isProTier } from "./entitlements";

describe("isProTier", () => {
  it.each([
    ["pepinillo_plus", true],
    ["everywhere_monthly", true],
    ["everywhere_annual", true],
    ["free", false],
    ["", false],
  ])("tier %s -> %s", (tier, expected) => {
    expect(isProTier(tier)).toBe(expected);
  });

  it("fails closed on null, undefined and unknown tiers", () => {
    expect(isProTier(null)).toBe(false);
    expect(isProTier(undefined)).toBe(false);
    expect(isProTier("something_new")).toBe(false);
  });

  it("is case-insensitive and keeps legacy everywhere aliases", () => {
    expect(isProTier("Pepinillo_Plus")).toBe(true);
    expect(isProTier("everywhere_plus")).toBe(true);
  });
});
