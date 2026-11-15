import { describe, expect, it } from "vitest";
import {
  adoptSessions,
  adoptTasks,
  energyFromServer,
  modeFromServer,
  modeToServer,
  priorityFromServer,
  priorityToServer,
  sessionFromServer,
  sessionToServer,
  taskFromServer,
  taskToServer,
} from "./mappers";
import type { SessionRecord } from "../focus/engine";
import type { Task } from "../tasks/tasks";

const TASK: Task = {
  id: "abc",
  title: "T",
  notes: "n",
  done: false,
  doneAtISO: null,
  priority: "high",
  energy: "deep",
  pomodoros: 0,
  today: true,
  dueISO: "2030-01-02T12:00:00.000Z",
  recurrence: "weekly",
  subtasks: [{ id: "s1", title: "sub", done: true }],
  createdAtISO: "2026-11-01T10:00:00.000Z",
  order: 1,
};

const SES: SessionRecord = {
  id: "s1",
  mode: "timeBlock",
  startedAtISO: "2026-11-15T10:00:00.000Z",
  durationSec: 3600,
  completed: true,
};

describe("task mapping", () => {
  it("maps fields incl. priority int and subtasks", () => {
    const out = taskToServer(TASK, "2026-11-15T12:00:00.000Z");
    expect(out).toMatchObject({
      syncId: "abc",
      title: "T",
      energyLevel: "deep",
      recurrenceRule: "weekly",
      isFinished: false,
      priority: 3,
      finishDate: "2030-01-02T12:00:00.000Z",
      updatedAt: "2026-11-15T12:00:00.000Z",
    });
    expect(out.subTasks).toEqual([{ title: "sub", isFinished: true }]);
  });

  it("done tasks send doneAt as finishDate", () => {
    const out = taskToServer(
      { ...TASK, done: true, doneAtISO: "2026-11-14T10:00:00.000Z" },
      "2026-11-15T12:00:00.000Z",
    );
    expect(out.finishDate).toBe("2026-11-14T10:00:00.000Z");
  });

  it("priority round-trips and clamps", () => {
    expect(priorityToServer("medium")).toBe(2);
    expect(priorityFromServer(3)).toBe("high");
    expect(priorityFromServer(99)).toBe("none");
  });

  it("adopts server tasks, dropping invalid", () => {
    const adopted = adoptTasks([
      { syncId: "x", title: "S", priority: 2, energyLevel: "foco" },
      { nope: 1 },
    ]);
    expect(adopted).toHaveLength(1);
    expect(adopted[0]).toMatchObject({ id: "x", priority: "medium", energy: "deep", order: 1 });
  });
});

describe("session mapping", () => {
  it("timeBlock maps to timeblock with endedAt math", () => {
    const out = sessionToServer(SES, "2026-11-15T12:00:00.000Z");
    expect(out).toMatchObject({
      mode: "timeblock",
      phase: "work",
      durationSeconds: 3600,
      wasCompleted: true,
    });
    expect(out.endedAt).toBe("2026-11-15T11:00:00.000Z");
  });

  it("adopts server sessions, dropping invalid", () => {
    const adopted = adoptSessions([
      { id: "a", mode: "flowtime", startedAt: "2026-11-15T10:00:00.000Z", durationSeconds: 600, wasCompleted: false },
      {},
    ]);
    expect(adopted).toEqual([
      { id: "a", mode: "flowtime", startedAtISO: "2026-11-15T10:00:00.000Z", durationSec: 600, completed: false },
    ]);
  });

  it("mode fallbacks stay sane", () => {
    expect(modeToServer("stopwatch")).toBe("stopwatch");
    expect(modeFromServer("timeblock")).toBe("timeBlock");
    expect(modeFromServer("???")).toBe("pomodoro");
    expect(energyFromServer("x")).toBe("deep");
    expect(taskFromServer({})).toBeNull();
    expect(sessionFromServer({})).toBeNull();
  });
});
