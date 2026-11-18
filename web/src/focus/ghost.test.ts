import { describe, expect, it } from "vitest";
import {
  elapsedAt,
  loadGhost,
  parseSnapshot,
  type ActiveSnapshot,
  type StorageLike,
} from "./ghost";
import { startRun } from "./engine";

function memory(fixture: Record<string, string> = {}): StorageLike {
  const mem = new Map(Object.entries(fixture));
  return {
    getItem: (k) => mem.get(k) ?? null,
    setItem: (k, v) => void mem.set(k, v),
    removeItem: (k) => void mem.delete(k),
  };
}

function snap(over: Partial<ActiveSnapshot> = {}): ActiveSnapshot {
  return {
    run: startRun("pomodoro", "2026-11-15T10:00:00.000Z"),
    base: 600,
    since: null,
    paused: true,
    savedAt: new Date("2026-11-15T10:10:00.000Z").getTime(),
    ...over,
  };
}

const NOW = new Date("2026-11-15T10:12:00.000Z").getTime();

describe("parseSnapshot", () => {
  it("rejects corrupt or partial snapshots", () => {
    expect(parseSnapshot(null)).toBeNull();
    expect(parseSnapshot("{nope")).toBeNull();
    expect(parseSnapshot(JSON.stringify({ run: { mode: "x" } }))).toBeNull();
    expect(parseSnapshot(JSON.stringify(snap()))).not.toBeNull();
  });
});

describe("elapsedAt", () => {
  it("freezes while paused", () => {
    expect(elapsedAt(snap({ base: 600, paused: true }), NOW)).toBe(600);
  });

  it("advances while running", () => {
    const s = snap({ base: 600, paused: false, since: NOW - 120_000 });
    expect(elapsedAt(s, NOW)).toBeCloseTo(720, 0);
  });
});

describe("loadGhost", () => {
  it("offers a fresh snapshot", () => {
    const store = memory({
      "pepinillo:active-run.v1": JSON.stringify(snap()),
    });
    const out = loadGhost(store, NOW);
    expect(out.kind).toBe("offer");
    if (out.kind !== "offer") return;
    expect(out.elapsedSec).toBe(600);
  });

  it("marks day-old snapshots stale", () => {
    const store = memory({
      "pepinillo:active-run.v1": JSON.stringify(
        snap({ savedAt: NOW - 25 * 3600_000, paused: false, since: NOW - 25 * 3600_000, base: 300 }),
      ),
    });
    const out = loadGhost(store, NOW);
    expect(out.kind).toBe("stale");
  });

  it("returns none when empty or storage throws", () => {
    expect(loadGhost(memory(), NOW)).toEqual({ kind: "none" });
    const throwing: StorageLike = {
      getItem: () => {
        throw new Error("denied");
      },
      setItem: () => {},
      removeItem: () => {},
    };
    expect(loadGhost(throwing, NOW)).toEqual({ kind: "none" });
  });
});
