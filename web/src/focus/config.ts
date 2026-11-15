/* Focus configuration — mirrors FocusConfig (FocusModels.swift) plus the
   iPad Settings flags (sounds, haptics, screen, reflection, celebration,
   notifications). Persisted locally; server UserPreferences sync arrives
   with continuous sync. Durations are clamped so a corrupt store can't
   produce a 0-second pomodoro. */

export interface FocusConfig {
  pomodoroSec: number;
  shortBreakSec: number;
  longBreakSec: number;
  pomodorosPerCycle: number;
  autoStartBreaks: boolean;
  autoStartWork: boolean;
  blockSec: number;
  flowMinSec: number;
  soundEnabled: boolean;
  completionSound: boolean;
  hapticsEnabled: boolean;
  keepScreenOn: boolean;
  reflectionEnabled: boolean;
  celebrateRecords: boolean;
  sessionAlerts: boolean;
  dailyReminder: boolean;
  dailyReminderHour: number;
  weeklyRecap: boolean;
}

export const DEFAULT_CONFIG: FocusConfig = {
  pomodoroSec: 25 * 60,
  shortBreakSec: 5 * 60,
  longBreakSec: 15 * 60,
  pomodorosPerCycle: 4,
  autoStartBreaks: true,
  autoStartWork: false,
  blockSec: 60 * 60,
  flowMinSec: 5 * 60,
  soundEnabled: true,
  completionSound: true,
  hapticsEnabled: true,
  keepScreenOn: false,
  reflectionEnabled: true,
  celebrateRecords: true,
  sessionAlerts: false,
  dailyReminder: false,
  dailyReminderHour: 9,
  weeklyRecap: false,
};

const CONFIG_KEY = "pepinillo:focus-config.v1";

function clampNum(v: unknown, min: number, max: number, fallback: number): number {
  return typeof v === "number" && Number.isFinite(v) ? Math.min(max, Math.max(min, v)) : fallback;
}

function clampBool(v: unknown, fallback: boolean): boolean {
  return typeof v === "boolean" ? v : fallback;
}

export function normalizeConfig(raw: unknown): FocusConfig {
  const r = (typeof raw === "object" && raw !== null ? raw : {}) as Partial<FocusConfig>;
  return {
    pomodoroSec: clampNum(r.pomodoroSec, 5 * 60, 120 * 60, DEFAULT_CONFIG.pomodoroSec),
    shortBreakSec: clampNum(r.shortBreakSec, 60, 30 * 60, DEFAULT_CONFIG.shortBreakSec),
    longBreakSec: clampNum(r.longBreakSec, 5 * 60, 60 * 60, DEFAULT_CONFIG.longBreakSec),
    pomodorosPerCycle: Math.round(clampNum(r.pomodorosPerCycle, 2, 8, DEFAULT_CONFIG.pomodorosPerCycle)),
    autoStartBreaks: clampBool(r.autoStartBreaks, true),
    autoStartWork: clampBool(r.autoStartWork, false),
    blockSec: clampNum(r.blockSec, 15 * 60, 4 * 3600, DEFAULT_CONFIG.blockSec),
    flowMinSec: clampNum(r.flowMinSec, 60, 30 * 60, DEFAULT_CONFIG.flowMinSec),
    soundEnabled: clampBool(r.soundEnabled, true),
    completionSound: clampBool(r.completionSound, true),
    hapticsEnabled: clampBool(r.hapticsEnabled, true),
    keepScreenOn: clampBool(r.keepScreenOn, false),
    reflectionEnabled: clampBool(r.reflectionEnabled, true),
    celebrateRecords: clampBool(r.celebrateRecords, true),
    sessionAlerts: clampBool(r.sessionAlerts, false),
    dailyReminder: clampBool(r.dailyReminder, false),
    dailyReminderHour: Math.round(clampNum(r.dailyReminderHour, 0, 23, 9)),
    weeklyRecap: clampBool(r.weeklyRecap, false),
  };
}

export interface ConfigStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

export function loadConfig(storage: ConfigStorage | null): FocusConfig {
  if (!storage) return { ...DEFAULT_CONFIG };
  try {
    return normalizeConfig(JSON.parse(storage.getItem(CONFIG_KEY) ?? "null"));
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

export function saveConfig(storage: ConfigStorage | null, config: FocusConfig): boolean {
  if (!storage) return false;
  try {
    storage.setItem(CONFIG_KEY, JSON.stringify(config));
    return true;
  } catch {
    return false;
  }
}

export function loadBrowserConfig(): FocusConfig {
  try {
    return typeof localStorage !== "undefined" ? loadConfig(localStorage) : { ...DEFAULT_CONFIG };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

export function saveBrowserConfig(config: FocusConfig): boolean {
  try {
    return typeof localStorage !== "undefined" ? saveConfig(localStorage, config) : false;
  } catch {
    return false;
  }
}
