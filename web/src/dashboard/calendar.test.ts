import { describe, expect, it } from "vitest";
import { buildMonth } from "./calendar";

describe("buildMonth", () => {
  it("builds 6 Monday-first weeks mapping minutes and dues", () => {
    const weeks = buildMonth(
      2026,
      10,
      [
        { id: "s", mode: "pomodoro", startedAtISO: "2026-11-15T10:00:00.000Z", durationSec: 1500, completed: true, taskId: null },
      ],
      [
        { dueISO: "2026-11-15T12:00:00.000Z", done: false },
        { dueISO: "2026-11-15T12:00:00.000Z", done: true },
      ],
    );
    expect(weeks).toHaveLength(6);
    expect(weeks[0]).toHaveLength(7);
    // 2026-11-01 is a Sunday: first cell is Monday 2026-10-26.
    expect(weeks[0][0].key).toBe("2026-10-26");
    expect(weeks[0][0].inMonth).toBe(false);
    const flat = weeks.flat();
    const day15 = flat.find((d) => d.key === "2026-11-15");
    expect(day15?.minutes).toBe(25);
    expect(day15?.tasksDue).toBe(1);
    expect(day15?.inMonth).toBe(true);
  });
});
