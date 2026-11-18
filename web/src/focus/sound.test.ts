import { describe, expect, it } from "vitest";
import { SOUNDSCAPES, parseSoundscape } from "./sound";

describe("parseSoundscape", () => {
  it("accepts known presets, falls back to none", () => {
    expect(parseSoundscape("rain")).toBe("rain");
    expect(parseSoundscape("white")).toBe("white");
    expect(parseSoundscape(null)).toBe("none");
    expect(parseSoundscape("ocean")).toBe("none");
    expect(parseSoundscape(undefined)).toBe("none");
  });

  it("lists none + two generated presets", () => {
    expect(SOUNDSCAPES.map((s) => s.id)).toEqual(["none", "rain", "white"]);
  });
});
