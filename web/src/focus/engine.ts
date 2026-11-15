/* Focus engine — pure logic, no React.
   Mirrors FocusModels.swift + the four strategies
   (ios/Features/Focus/Modes/*.swift): same defaults, same phase flow:
   Pomodoro 25/5/15 x4 con auto-inicio de descansos; Bloque 60 min;
   Flowtime ascendente con descanso sugerido; Cronómetro libre. */

export type Mode = "pomodoro" | "flowtime" | "timeBlock" | "stopwatch";

export type Phase =
  | "idle"
  | "work"
  | "shortBreak"
  | "longBreak"
  | "flow"
  | "flowBreak"
  | "block"
  | "freeform";

export interface ModeMeta {
  id: Mode;
  name: string;
  detail: string;
  glyph: string;
  free: boolean;
  countsDown: boolean;
}

export const MODES: ModeMeta[] = [
  { id: "pomodoro", name: "Pomodoro", detail: "25 min de enfoque · descansos de 5 y 15", glyph: "🍅", free: true, countsDown: true },
  { id: "flowtime", name: "Flowtime", detail: "Cuenta ascendente · descanso sugerido", glyph: "🌊", free: false, countsDown: false },
  { id: "timeBlock", name: "Bloque", detail: "Un bloque continuo de 60 min", glyph: "📦", free: false, countsDown: true },
  { id: "stopwatch", name: "Cronómetro", detail: "Enfoque libre sin objetivo", glyph: "⏱", free: true, countsDown: false },
];

import { DEFAULT_CONFIG, type FocusConfig } from "./config";

export type { FocusConfig };

/** Engine defaults = the iPad FocusConfig defaults. Slices that accept a
    user config take `cfg: FocusConfig = DEFAULTS`. */
export const DEFAULTS = { ...DEFAULT_CONFIG };

export interface Run {
  mode: Mode;
  phase: Phase;
  /** Linked task id (TaskPicker parity). Null when the session is free. */
  taskId: string | null;
  /** Pomodoro work number within the cycle (1-based). */
  pomo: number;
  pomoTotal: number;
  /** Seconds elapsed in the current phase (excludes pauses). */
  elapsedSec: number;
  /** Target seconds for countdown phases; null for count-up. */
  targetSec: number | null;
  startedAtISO: string;
  /** Flow seconds banked before taking a Flowtime break. */
  flowSec?: number;
}

export interface SessionRecord {
  id: string;
  mode: Mode;
  startedAtISO: string;
  durationSec: number;
  completed: boolean;
  taskId: string | null;
  /** Post-session reflection (journal). Absent until the user writes it. */
  rating?: number;
  note?: string;
}

export function startRun(
  mode: Mode,
  nowISO: string,
  taskId: string | null = null,
  cfg: FocusConfig = DEFAULTS,
): Run {
  switch (mode) {
    case "pomodoro":
      return { mode, phase: "work", taskId, pomo: 1, pomoTotal: cfg.pomodorosPerCycle, elapsedSec: 0, targetSec: cfg.pomodoroSec, startedAtISO: nowISO };
    case "timeBlock":
      return { mode, phase: "block", taskId, pomo: 1, pomoTotal: 1, elapsedSec: 0, targetSec: cfg.blockSec, startedAtISO: nowISO };
    case "flowtime":
      return { mode, phase: "flow", taskId, pomo: 1, pomoTotal: 1, elapsedSec: 0, targetSec: null, startedAtISO: nowISO };
    case "stopwatch":
      return { mode, phase: "freeform", taskId, pomo: 1, pomoTotal: 1, elapsedSec: 0, targetSec: null, startedAtISO: nowISO };
  }
}

/** Suggested Flowtime break: 1/5 of the flow, clamped 5–15 min. */
export function suggestedBreakSec(flowElapsedSec: number): number {
  return Math.min(15 * 60, Math.max(5 * 60, Math.round(flowElapsedSec / 5)));
}

export type TickResult =
  | { kind: "tick"; run: Run }
  /** A work unit finished: save `record`, then continue with `next`
      only when `autostart` (autoStartBreaks, iPad default true). */
  | { kind: "workComplete"; record: SessionRecord; next: Run; autostart: boolean }
  /** A break finished: continue with `next` work only when `autostart`
      (autoStartWork, iPad default false — the user starts the next unit). */
  | { kind: "breakComplete"; next: Run; autostart: boolean }
  | { kind: "blockComplete"; record: SessionRecord }
  /** Flow break finished: the flow itself lasted `flowDurationSec`. */
  | { kind: "flowBreakComplete"; flowDurationSec: number };

function makeRecord(run: Run, durationSec: number, completed: boolean): SessionRecord {
  return {
    id: `${Date.now()}-${Math.floor(Math.random() * 1e6)}`,
    mode: run.mode,
    startedAtISO: run.startedAtISO,
    durationSec: Math.round(durationSec),
    completed,
    taskId: run.taskId ?? null,
  };
}

/** Advance one second. Pure: same input always yields the same output. */
export function tick(run: Run, dtSec = 1, cfg: FocusConfig = DEFAULTS): TickResult {
  const elapsedSec = run.elapsedSec + dtSec;
  if (run.targetSec == null) return { kind: "tick", run: { ...run, elapsedSec } };
  if (elapsedSec < run.targetSec) return { kind: "tick", run: { ...run, elapsedSec } };

  switch (run.phase) {
    case "work": {
      const isLast = run.pomo >= run.pomoTotal;
      const breakPhase: Phase = isLast ? "longBreak" : "shortBreak";
      return {
        kind: "workComplete",
        record: makeRecord(run, cfg.pomodoroSec, true),
        next: {
          ...run,
          phase: breakPhase,
          elapsedSec: 0,
          targetSec: isLast ? cfg.longBreakSec : cfg.shortBreakSec,
        },
        autostart: cfg.autoStartBreaks,
      };
    }
    case "shortBreak":
    case "longBreak": {
      const finishedCycle = run.phase === "longBreak";
      return {
        kind: "breakComplete",
        next: {
          ...run,
          phase: "work",
          pomo: finishedCycle ? 1 : run.pomo + 1,
          elapsedSec: 0,
          targetSec: cfg.pomodoroSec,
        },
        autostart: cfg.autoStartWork && !finishedCycle,
      };
    }
    case "block":
      return { kind: "blockComplete", record: makeRecord(run, run.targetSec, true) };
    case "flowBreak":
      return { kind: "flowBreakComplete", flowDurationSec: run.flowSec ?? run.elapsedSec };
    default:
      return { kind: "tick", run: { ...run, elapsedSec } };
  }
}

/** Stop early: records the session only if it lasted at least 30 s. */
export function stopEarly(run: Run, nowISO: string): SessionRecord | null {
  void nowISO;
  if (run.elapsedSec < 30) return null;
  return {
    id: `${Date.now()}-${Math.floor(Math.random() * 1e6)}`,
    mode: run.mode,
    startedAtISO: run.startedAtISO,
    durationSec: Math.round(run.elapsedSec),
    completed: false,
    taskId: run.taskId ?? null,
  };
}

export function phaseLabel(run: Run | null, nextPomo: number): string {
  if (!run) return `Listo · Pomodoro ${nextPomo}/${DEFAULTS.pomodorosPerCycle}`;
  switch (run.phase) {
    case "work": return `Enfoque ${run.pomo}/${run.pomoTotal}`;
    case "shortBreak": return "Descanso corto";
    case "longBreak": return "Descanso largo";
    case "flow": return "Fluyendo";
    case "flowBreak": return "Descanso";
    case "block": return "Bloque de tiempo";
    case "freeform": return "Enfoque libre";
    default: return "Listo";
  }
}

export function formatClock(totalSec: number): string {
  const s = Math.max(0, Math.floor(totalSec));
  const m = Math.floor(s / 60);
  const r = s % 60;
  const h = Math.floor(m / 60);
  if (h > 0) return `${h}:${String(m % 60).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
  return `${m}:${String(r).padStart(2, "0")}`;
}
