import { describe, expect, it } from "vitest";
import {
  achievements,
  bestDayMinutes,
  perDaySeries,
  streakDays,
  suggestBestMode,
  summarizeRange,
  summarizeToday,
  taskBreakdown,
  trendPct,
} from "./stats";
import type { SessionRecord } from "./engine";

function rec(day: string, durationSec: number, completed = true): SessionRecord {
  return {
    id: day + durationSec,
    mode: "pomodoro",
    startedAtISO: `${day}T10:00:00.000Z`,
    durationSec,
    completed,
    taskId: null,
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

describe("perDaySeries", () => {
  it("returns oldest-first points with zeros", () => {
    const pts = perDaySeries([rec("2026-11-15", 600)], 3, NOW);
    expect(pts).toHaveLength(3);
    expect(pts[2]).toEqual({ day: "2026-11-15", minutes: 10, sessions: 1 });
    expect(pts[0]).toEqual({ day: "2026-11-13", minutes: 0, sessions: 0 });
  });
});

describe("summarizeRange", () => {
  it("aggregates the window with per-mode minutes", () => {
    const sessions = [
      { ...rec("2026-11-15", 1500), mode: "pomodoro" as const },
      { ...rec("2026-11-15", 900), mode: "flowtime" as const },
      { ...rec("2026-11-10", 1500), mode: "pomodoro" as const },
    ];
    const sum = summarizeRange(sessions, "2026-11-14T00:00:00", "2026-11-16T00:00:00");
    expect(sum).toMatchObject({ sessions: 2, completed: 2, focusMin: 40, activeDays: 1 });
    expect(sum.perMode.pomodoro).toBe(25);
    expect(sum.perMode.flowtime).toBe(15);
  });
});

describe("trendPct", () => {
  it("computes change and stays null without baseline", () => {
    expect(trendPct(150, 100)).toBe(50);
    expect(trendPct(50, 100)).toBe(-50);
    expect(trendPct(10, 0)).toBeNull();
  });
});

describe("achievements", () => {
  it("unlocks by thresholds", () => {
    const none = achievements([], 0, NOW);
    expect(none.every((a) => !a.earned)).toBe(true);
    const some = achievements([rec("2026-11-15", 1500)], 0, NOW);
    expect(some.find((a) => a.id === "first")?.earned).toBe(true);
    expect(some.find((a) => a.id === "century")?.earned).toBe(false);
  });
});

describe("taskBreakdown", () => {
  it("groups linked sessions best-first, skipping unlinked", () => {
    const sessions = [
      { ...rec("2026-11-15", 600), id: "a", taskId: "t1" },
      { ...rec("2026-11-15", 1200), id: "b", taskId: "t2" },
      { ...rec("2026-11-15", 600), id: "c", taskId: null },
    ];
    expect(taskBreakdown(sessions)).toEqual([
      { taskId: "t2", sessions: 1, minutes: 20 },
      { taskId: "t1", sessions: 1, minutes: 10 },
    ]);
  });
});
