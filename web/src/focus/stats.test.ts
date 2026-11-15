import { describe, expect, it } from "vitest";
import { streakDays, summarizeToday } from "./stats";
import type { SessionRecord } from "./engine";

function rec(day: string, durationSec: number, completed = true): SessionRecord {
  return {
    id: day + durationSec,
    mode: "pomodoro",
    startedAtISO: `${day}T10:00:00.000Z`,
    durationSec,
    completed,
  };
}

const NOW = new Date("2026-11-15T20:00:00");

describe("summarizeToday", () => {
  it("counts only today's sessions", () => {
    const sessions = [rec("2026-11-15", 1500), rec("2026-11-15", 300, false), rec("2026-11-14", 1500)];
    const sum = summarizeToday(sessions, NOW);
    expect(sum.sessions).toBe(2);
    expect(sum.completed).toBe(1);
    expect(sum.focusMin).toBe(30);
  });
});

describe("streakDays", () => {
  it("counts consecutive days ending today", () => {
    const sessions = [rec("2026-11-15", 900), rec("2026-11-14", 900), rec("2026-11-13", 900)];
    expect(streakDays(sessions, NOW)).toBe(3);
  });

  it("survives when today is still empty", () => {
    const sessions = [rec("2026-11-14", 900), rec("2026-11-13", 900)];
    expect(streakDays(sessions, NOW)).toBe(2);
  });

  it("breaks on a gap and ignores sub-minute sessions", () => {
    const sessions = [rec("2026-11-15", 900), rec("2026-11-13", 900), rec("2026-11-12", 20)];
    expect(streakDays(sessions, NOW)).toBe(1);
  });

  it("is zero with no sessions", () => {
    expect(streakDays([], NOW)).toBe(0);
  });
});
