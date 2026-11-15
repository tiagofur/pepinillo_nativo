import { useCallback, useEffect, useRef, useState } from "react";
import {
  DEFAULTS,
  startRun,
  stopEarly,
  suggestedBreakSec,
  tick,
  type Mode,
  type Run,
  type SessionRecord,
} from "./engine";

const JOURNAL_KEY = "pepinillo:sessions.v1";
const MAX_JOURNAL = 500;

export function loadSessions(): SessionRecord[] {
  try {
    const raw = localStorage.getItem(JOURNAL_KEY);
    if (!raw) return [];
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as SessionRecord[]) : [];
  } catch {
    return [];
  }
}

export interface FocusApi {
  run: Run | null;
  paused: boolean;
  /** Next work unit parked after a break (the iPad waits for the user). */
  pending: Run | null;
  saveError: boolean;
  flash: string | null;
  suggestBreak: boolean;
  start: (mode: Mode) => void;
  startPending: () => void;
  pause: () => void;
  resume: () => void;
  stop: () => void;
  takeFlowBreak: () => void;
  skipBreak: () => void;
  retrySave: () => void;
  dismissFlash: () => void;
}

export function useFocus(): FocusApi {
  const [run, setRun] = useState<Run | null>(null);
  const [paused, setPaused] = useState(false);
  const [pending, setPending] = useState<Run | null>(null);
  const [saveError, setSaveError] = useState(false);
  const [flash, setFlash] = useState<string | null>(null);
  const [failedRecord, setFailedRecord] = useState<SessionRecord | null>(null);
  /** Elapsed seconds banked before the current running stretch. */
  const baseRef = useRef(0);
  /** Timestamp (ms) when the current stretch started; null while paused. */
  const sinceRef = useRef<number | null>(null);
  /** Mirror of `run` for the interval: transitions run here as plain code,
      never inside a state updater (StrictMode double-invokes updaters,
      which would save sessions twice). */
  const runRef = useRef<Run | null>(null);
  runRef.current = run;

  const persist = useCallback((record: SessionRecord): boolean => {
    try {
      const journal = loadSessions();
      journal.push(record);
      localStorage.setItem(JOURNAL_KEY, JSON.stringify(journal.slice(-MAX_JOURNAL)));
      return true;
    } catch {
      setFailedRecord(record);
      setSaveError(true);
      return false;
    }
  }, []);

  const effectiveElapsed = useCallback((r: Run): number => {
    void r;
    const since = sinceRef.current;
    if (since == null) return baseRef.current;
    return baseRef.current + (Date.now() - since) / 1000;
  }, []);

  const park = useCallback((next: Run) => {
    setRun(null);
    setPaused(false);
    sinceRef.current = null;
    setPending({ ...next, elapsedSec: 0 });
  }, []);

  const active = run != null && !paused;

  // 4 Hz clock: timestamp-based so background throttling can't lose time.
  useEffect(() => {
    if (!active) return;
    const id = window.setInterval(() => {
      const prev = runRef.current;
      if (!prev) return;
      const eff = effectiveElapsed(prev);
      if (prev.targetSec == null || eff < prev.targetSec) {
        setRun({ ...prev, elapsedSec: eff });
        return;
      }
      const out = tick({ ...prev, elapsedSec: prev.targetSec }, 0);
      switch (out.kind) {
        case "tick":
          baseRef.current = out.run.elapsedSec;
          sinceRef.current = Date.now();
          setRun(out.run);
          break;
        case "workComplete":
          persist(out.record);
          if (out.autostart) {
            baseRef.current = 0;
            sinceRef.current = Date.now();
            setRun(out.next);
          } else {
            park(out.next);
          }
          break;
        case "breakComplete":
          if (out.autostart) {
            baseRef.current = 0;
            sinceRef.current = Date.now();
            setRun(out.next);
          } else {
            park(out.next);
          }
          break;
        case "blockComplete":
          persist(out.record);
          sinceRef.current = null;
          setRun(null);
          setFlash("¡Bloque completado! Buen trabajo.");
          break;
        case "flowBreakComplete":
          persist({
            id: `${Date.now()}-${Math.floor(Math.random() * 1e6)}`,
            mode: prev.mode,
            startedAtISO: prev.startedAtISO,
            durationSec: Math.round(out.flowDurationSec),
            completed: out.flowDurationSec >= DEFAULTS.flowMinSec,
          });
          sinceRef.current = null;
          setRun(null);
          setFlash("Descanso terminado. Vuelve cuando quieras.");
          break;
      }
    }, 250);
    return () => window.clearInterval(id);
  }, [active, effectiveElapsed, park, persist]);

  // Live tab title while running (restored when idle).
  useEffect(() => {
    if (!run) {
      document.title = "Pepinillo — Deep Work Companion";
      return;
    }
    const shown =
      run.targetSec != null ? Math.max(0, run.targetSec - run.elapsedSec) : run.elapsedSec;
    const m = Math.floor(shown / 60);
    const s = Math.floor(shown % 60);
    const h = Math.floor(m / 60);
    const clock =
      h > 0
        ? `${h}:${String(m % 60).padStart(2, "0")}:${String(s).padStart(2, "0")}`
        : `${m}:${String(s).padStart(2, "0")}`;
    document.title = `${clock} · Pepinillo`;
  }, [run]);

  const start = useCallback((mode: Mode) => {
    const now = new Date();
    baseRef.current = 0;
    sinceRef.current = now.getTime();
    setPending(null);
    setFlash(null);
    setPaused(false);
    setRun(startRun(mode, now.toISOString()));
  }, []);

  const startPending = useCallback(() => {
    const p = pending;
    if (!p) return;
    baseRef.current = 0;
    sinceRef.current = Date.now();
    setPending(null);
    setPaused(false);
    setFlash(null);
    setRun({ ...p, startedAtISO: new Date().toISOString() });
  }, [pending]);

  const pause = useCallback(() => {
    const prev = runRef.current;
    if (!prev) return;
    baseRef.current = effectiveElapsed(prev);
    sinceRef.current = null;
    setRun({ ...prev, elapsedSec: baseRef.current });
    setPaused(true);
  }, [effectiveElapsed]);

  const resume = useCallback(() => {
    sinceRef.current = Date.now();
    setPaused(false);
  }, []);

  const stop = useCallback(() => {
    const prev = runRef.current;
    if (!prev) return;
    const record = stopEarly(
      { ...prev, elapsedSec: effectiveElapsed(prev) },
      new Date().toISOString(),
    );
    if (record) persist(record);
    sinceRef.current = null;
    setPaused(false);
    setRun(null);
  }, [effectiveElapsed, persist]);

  const takeFlowBreak = useCallback(() => {
    const prev = runRef.current;
    if (!prev || prev.phase !== "flow") return;
    const flowSec = effectiveElapsed(prev);
    baseRef.current = 0;
    sinceRef.current = Date.now();
    setRun({
      ...prev,
      phase: "flowBreak",
      elapsedSec: 0,
      targetSec: suggestedBreakSec(flowSec),
      flowSec,
    });
  }, [effectiveElapsed]);

  const skipBreak = useCallback(() => {
    // Ending a break early parks the next work unit for the user to start.
    const prev = runRef.current;
    if (!prev) return;
    if (prev.phase !== "shortBreak" && prev.phase !== "longBreak") return;
    const finishedCycle = prev.phase === "longBreak";
    park({
      ...prev,
      phase: "work",
      pomo: finishedCycle ? 1 : prev.pomo + 1,
      elapsedSec: 0,
      targetSec: DEFAULTS.pomodoroSec,
    });
  }, [park]);

  const retrySave = useCallback(() => {
    const rec = failedRecord;
    if (rec && persist(rec)) {
      setSaveError(false);
      setFailedRecord(null);
    }
  }, [failedRecord, persist]);

  const suggestBreak =
    run?.mode === "flowtime" && run.phase === "flow" && run.elapsedSec >= DEFAULTS.flowMinSec;

  return {
    run,
    paused,
    pending,
    saveError,
    flash,
    suggestBreak,
    start,
    startPending,
    pause,
    resume,
    stop,
    takeFlowBreak,
    skipBreak,
    retrySave,
    dismissFlash: () => setFlash(null),
  };
}
