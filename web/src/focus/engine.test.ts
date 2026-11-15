import { describe, expect, it } from "vitest";
import {
  DEFAULTS,
  formatClock,
  startRun,
  stopEarly,
  suggestedBreakSec,
  tick,
} from "./engine";

const ISO = "2026-11-15T10:00:00.000Z";

describe("pomodoro", () => {
  it("work completes into an auto-started short break with a saved record", () => {
    const run = startRun("pomodoro", ISO);
    const out = tick({ ...run, elapsedSec: DEFAULTS.pomodoroSec }, 0);
    expect(out.kind).toBe("workComplete");
    if (out.kind !== "workComplete") return;
    expect(out.record.completed).toBe(true);
    expect(out.record.durationSec).toBe(DEFAULTS.pomodoroSec);
    expect(out.next.phase).toBe("shortBreak");
    expect(out.next.targetSec).toBe(DEFAULTS.shortBreakSec);
    expect(out.autostart).toBe(true);
  });

  it("fourth work unit leads to a long break", () => {
    const run = { ...startRun("pomodoro", ISO), pomo: 4 };
    const out = tick({ ...run, elapsedSec: DEFAULTS.pomodoroSec }, 0);
    expect(out.kind).toBe("workComplete");
    if (out.kind !== "workComplete") return;
    expect(out.next.phase).toBe("longBreak");
    expect(out.next.targetSec).toBe(DEFAULTS.longBreakSec);
  });

  it("break end parks the next work unit for the user (no autostart)", () => {
    const run = startRun("pomodoro", ISO);
    const work = tick({ ...run, elapsedSec: DEFAULTS.pomodoroSec }, 0);
    expect(work.kind).toBe("workComplete");
    if (work.kind !== "workComplete") return;
    const brk = tick({ ...work.next, elapsedSec: DEFAULTS.shortBreakSec }, 0);
    expect(brk.kind).toBe("breakComplete");
    if (brk.kind !== "breakComplete") return;
    expect(brk.autostart).toBe(false);
    expect(brk.next.phase).toBe("work");
    expect(brk.next.pomo).toBe(2);
  });

  it("long break resets the cycle to 1", () => {
    const run = { ...startRun("pomodoro", ISO), pomo: 4, phase: "longBreak" as const, targetSec: DEFAULTS.longBreakSec };
    const out = tick({ ...run, elapsedSec: DEFAULTS.longBreakSec }, 0);
    expect(out.kind).toBe("breakComplete");
    if (out.kind !== "breakComplete") return;
    expect(out.next.pomo).toBe(1);
  });
});

describe("other modes", () => {
  it("time block completes with its record", () => {
    const run = startRun("timeBlock", ISO);
    expect(run.targetSec).toBe(DEFAULTS.blockSec);
    const out = tick({ ...run, elapsedSec: DEFAULTS.blockSec }, 0);
    expect(out.kind).toBe("blockComplete");
  });

  it("flowtime counts up with no target", () => {
    const run = startRun("flowtime", ISO);
    const out = tick(run, 60);
    expect(out.kind).toBe("tick");
    if (out.kind !== "tick") return;
    expect(out.run.elapsedSec).toBe(60);
  });

  it("suggested break is 1/5 of flow, clamped 5–15 min", () => {
    expect(suggestedBreakSec(10 * 60)).toBe(5 * 60);
    expect(suggestedBreakSec(50 * 60)).toBe(10 * 60);
    expect(suggestedBreakSec(200 * 60)).toBe(15 * 60);
  });

  it("carries the linked task id into records", () => {
    const run = startRun("pomodoro", ISO, "t-9");
    expect(run.taskId).toBe("t-9");
    expect(startRun("pomodoro", ISO).taskId).toBeNull();
    const out = tick({ ...run, elapsedSec: DEFAULTS.pomodoroSec }, 0);
    expect(out.kind).toBe("workComplete");
    if (out.kind !== "workComplete") return;
    expect(out.record.taskId).toBe("t-9");
  });

  it("stop before 30s records nothing", () => {
    const run = { ...startRun("stopwatch", ISO), elapsedSec: 29 };
    expect(stopEarly(run, ISO)).toBeNull();
  });

  it("early stop records an uncompleted session", () => {
    const run = { ...startRun("stopwatch", ISO), elapsedSec: 90 };
    const rec = stopEarly(run, ISO);
    expect(rec?.completed).toBe(false);
    expect(rec?.durationSec).toBe(90);
  });
});

describe("formatClock", () => {
  it("formats m:ss and h:mm:ss", () => {
    expect(formatClock(0)).toBe("0:00");
    expect(formatClock(1500)).toBe("25:00");
    expect(formatClock(3661)).toBe("1:01:01");
  });
});
