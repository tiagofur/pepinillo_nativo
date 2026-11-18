import { describe, expect, it } from "vitest";
import {
  DEFAULT_CONFIG,
  loadConfig,
  normalizeConfig,
  saveConfig,
  type ConfigStorage,
} from "./config";

function memory(fixture: Record<string, string> = {}): ConfigStorage {
  const mem = new Map(Object.entries(fixture));
  return {
    getItem: (k) => mem.get(k) ?? null,
    setItem: (k, v) => void mem.set(k, v),
  };
}

describe("normalizeConfig", () => {
  it("returns defaults for empty or corrupt input", () => {
    expect(normalizeConfig(null)).toEqual(DEFAULT_CONFIG);
    expect(normalizeConfig("nope")).toEqual(DEFAULT_CONFIG);
    expect(normalizeConfig({})).toEqual(DEFAULT_CONFIG);
  });

  it("clamps durations and counts into sane ranges", () => {
    const c = normalizeConfig({ pomodoroSec: 0, shortBreakSec: 99999, pomodorosPerCycle: 99, dailyReminderHour: 30 });
    expect(c.pomodoroSec).toBe(5 * 60);
    expect(c.shortBreakSec).toBe(30 * 60);
    expect(c.pomodorosPerCycle).toBe(8);
    expect(c.dailyReminderHour).toBe(23);
  });

  it("rejects non-boolean flags", () => {
    const c = normalizeConfig({ soundEnabled: "yes", keepScreenOn: 1 });
    expect(c.soundEnabled).toBe(true);
    expect(c.keepScreenOn).toBe(false);
  });

  it("keeps valid custom values", () => {
    const c = normalizeConfig({ pomodoroSec: 50 * 60, autoStartWork: true, dailyReminderHour: 7 });
    expect(c.pomodoroSec).toBe(50 * 60);
    expect(c.autoStartWork).toBe(true);
    expect(c.dailyReminderHour).toBe(7);
  });
});

describe("load/save round-trip", () => {
  it("persists and restores", () => {
    const store = memory();
    expect(saveConfig(store, { ...DEFAULT_CONFIG, pomodoroSec: 40 * 60 })).toBe(true);
    expect(loadConfig(store).pomodoroSec).toBe(40 * 60);
  });

  it("fails closed without storage", () => {
    expect(loadConfig(null)).toEqual(DEFAULT_CONFIG);
    expect(saveConfig(null, DEFAULT_CONFIG)).toBe(false);
  });
});
