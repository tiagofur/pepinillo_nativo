import { describe, expect, it } from "vitest";
import { buildExportCSV, buildExportJSON } from "./export";
import type { SessionRecord } from "../focus/engine";
import type { Task } from "../tasks/tasks";

const TASKS: Task[] = [
  {
    id: "t1",
    title: 'Escribir "informe", primero',
    notes: "",
    done: true,
    doneAtISO: "2026-11-15T11:00:00.000Z",
    priority: "high",
    energy: "deep",
    pomodoros: 2,
    today: true,
    createdAtISO: "2026-11-15T09:00:00.000Z",
    order: 1,
  },
];

const SESSIONS: SessionRecord[] = [
  { id: "s1", mode: "pomodoro", startedAtISO: "2026-11-15T10:00:00.000Z", durationSec: 1500, completed: true },
];

describe("export JSON", () => {
  it("round-trips tasks and sessions with metadata", () => {
    const parsed = JSON.parse(buildExportJSON(TASKS, SESSIONS, "2026-11-15T12:00:00.000Z"));
    expect(parsed.app).toBe("pepinillo-web");
    expect(parsed.tasks).toHaveLength(1);
    expect(parsed.sessions).toHaveLength(1);
    expect(parsed.exportedAtISO).toBe("2026-11-15T12:00:00.000Z");
  });
});

describe("export CSV", () => {
  it("escapes commas and quotes", () => {
    const csv = buildExportCSV(TASKS, SESSIONS);
    const lines = csv.trim().split("\n");
    expect(lines[0]).toBe("kind,id,title_or_mode,detail,done_or_minutes,at");
    expect(lines[1]).toContain('"Escribir ""informe"", primero"');
    expect(lines[2]).toContain("session,s1,pomodoro,completed,25,");
  });
});
