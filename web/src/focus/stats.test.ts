import { describe, expect, it } from "vitest";
import { bestDayMinutes, streakDays, suggestBestMode, summarizeToday } from "./stats";
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

describe("bestDayMinutes", () => {
  it("finds the best day", () => {
    const sessions = [rec("2026-11-15", 900), rec("2026-11-14", 1800), rec("2026-11-14", 600)];
    expect(bestDayMinutes(sessions)).toEqual({ day: "2026-11-14", minutes: 40 });
    expect(bestDayMinutes([])).toBeNull();
  });
});

describe("suggestBestMode", () => {
  it("picks the best completion rate with enough history", () => {
    const sessions = [
      { ...rec("2026-11-15", 1500), mode: "pomodoro" as const },
      { ...rec("2026-11-14", 1500), mode: "pomodoro" as const },
      { ...rec("2026-11-13", 1500, false), mode: "pomodoro" as const },
      { ...rec("2026-11-15", 900), mode: "stopwatch" as const },
      { ...rec("2026-11-14", 900), mode: "stopwatch" as const },
    ];
    expect(suggestBestMode(sessions)).toEqual({ mode: "stopwatch", rate: 1, sessions: 2 });
  });

  it("stays quiet without enough history", () => {
    expect(suggestBestMode([rec("2026-11-15", 1500)])).toBeNull();
    expect(suggestBestMode([])).toBeNull();
  });
});
