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
import { streakDays } from "./stats";
import {
  clearActiveRun,
  elapsedAt,
  loadGhost,
  saveActiveRun,
  type ActiveSnapshot,
} from "./ghost";
import type { FocusConfig } from "./config";

const JOURNAL_KEY = "pepinillo:sessions.v1";
const MAX_JOURNAL = 500;

/** Update one saved record with its post-session reflection. */
export function saveJournalEntry(id: string, rating: number | null, note: string): boolean {
  try {
    const journal = loadSessions();
    const next = journal.map((s) =>
      s.id === id ? { ...s, ...(rating != null ? { rating } : {}), note } : s,
    );
    localStorage.setItem(JOURNAL_KEY, JSON.stringify(next.slice(-MAX_JOURNAL)));
    return true;
  } catch {
    return false;
  }
}

function streakCopy(): string {
  const n = streakDays(loadSessions(), new Date());
  return `${n} ${n === 1 ? "día" : "días"}`;
}

function browserStorage(): Storage | null {
  try {
    return typeof localStorage !== "undefined" ? localStorage : null;
  } catch {
    return null;
  }
}

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
  pendingJournal: SessionRecord | null;
  start: (mode: Mode, taskId?: string | null) => void;
  ghost: { snapshot: ActiveSnapshot; elapsedSec: number } | null;
  startPending: () => void;
  pause: () => void;
  resume: () => void;
  stop: () => void;
  takeFlowBreak: () => void;
  skipBreak: () => void;
  retrySave: () => void;
  dismissFlash: () => void;
  completeJournal: (rating: number | null, note: string) => void;
  skipJournal: () => void;
  resumeGhost: () => void;
  discardGhost: () => void;
}

export function useFocus(config: FocusConfig): FocusApi {
  const [run, setRun] = useState<Run | null>(null);
  const [paused, setPaused] = useState(false);
  const [pending, setPending] = useState<Run | null>(null);
  const [saveError, setSaveError] = useState(false);
  const [flash, setFlash] = useState<string | null>(null);
  const [failedRecord, setFailedRecord] = useState<SessionRecord | null>(null);
  const [pendingJournal, setPendingJournal] = useState<SessionRecord | null>(null);
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
    const storage = browserStorage();
    if (storage) clearActiveRun(storage);
  }, []);

  const snapshotNow = useCallback((r: Run | null, pausedNow: boolean) => {
    const storage = browserStorage();
    if (!storage) return;
    if (!r) {
      clearActiveRun(storage);
      return;
    }
    saveActiveRun(storage, {
      run: r,
      base: baseRef.current,
      since: sinceRef.current,
      paused: pausedNow,
      savedAt: Date.now(),
    });
  }, []);

  const [ghost, setGhost] = useState<{ snapshot: ActiveSnapshot; elapsedSec: number } | null>(null);
  const ghostInitRef = useRef(false);

  // Ghost offer: an unfinished snapshot left by a previous visit.
  useEffect(() => {
    if (ghostInitRef.current) return;
    ghostInitRef.current = true;
    const storage = browserStorage();
    if (!storage) return;
    const loaded = loadGhost(storage, Date.now());
    if (loaded.kind === "offer") {
      setGhost({ snapshot: loaded.snapshot, elapsedSec: loaded.elapsedSec });
    } else if (loaded.kind === "stale") {
      if (loaded.elapsedSec >= 60) {
        persist({
          id: `ghost-${Date.now()}`,
          mode: loaded.snapshot.run.mode,
          startedAtISO: loaded.snapshot.run.startedAtISO,
          durationSec: Math.round(loaded.elapsedSec),
          completed: false,
          taskId: loaded.snapshot.run.taskId ?? null,
        });
      }
      clearActiveRun(storage);
    } else {
      clearActiveRun(storage);
    }
  }, [persist]);

  // Snapshot the live run so a closed tab can offer resume later.
  useEffect(() => {
    const onUnload = () => {
      const storage = browserStorage();
      if (!storage) return;
      const r = runRef.current;
      if (!r) {
        clearActiveRun(storage);
        return;
      }
      const since = sinceRef.current;
      saveActiveRun(storage, {
        run: r,
        base: baseRef.current,
        since,
        paused: since == null,
        savedAt: Date.now(),
      });
    };
    window.addEventListener("beforeunload", onUnload);
    return () => window.removeEventListener("beforeunload", onUnload);
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
      const out = tick({ ...prev, elapsedSec: prev.targetSec }, 0, config);
      switch (out.kind) {
        case "tick":
          baseRef.current = out.run.elapsedSec;
          sinceRef.current = Date.now();
          setRun(out.run);
          break;
        case "workComplete":
          persist(out.record);
          if (config.reflectionEnabled) setPendingJournal(out.record);
          setFlash(
            config.celebrateRecords
              ? `¡Enfoque completado! Racha: ${streakCopy()}. A descansar.`
              : "Enfoque completado. A descansar.",
          );
          if (out.autostart) {
            baseRef.current = 0;
            sinceRef.current = Date.now();
            setRun(out.next);
            snapshotNow(out.next, false);
          } else {
            park(out.next);
          }
          break;
        case "breakComplete":
          if (out.autostart) {
            baseRef.current = 0;
            sinceRef.current = Date.now();
            setRun(out.next);
            snapshotNow(out.next, false);
          } else {
            park(out.next);
          }
          break;
        case "blockComplete":
          persist(out.record);
          if (config.reflectionEnabled) setPendingJournal(out.record);
          sinceRef.current = null;
          setRun(null);
          snapshotNow(null, false);
          setFlash(
            config.celebrateRecords
              ? `¡Bloque completado! Racha: ${streakCopy()}.`
              : "Bloque completado.",
          );
          break;
        case "flowBreakComplete": {
          const rec: SessionRecord = {
            id: `${Date.now()}-${Math.floor(Math.random() * 1e6)}`,
            mode: prev.mode,
            startedAtISO: prev.startedAtISO,
            durationSec: Math.round(out.flowDurationSec),
            completed: out.flowDurationSec >= DEFAULTS.flowMinSec,
            taskId: prev.taskId ?? null,
          };
          persist(rec);
          if (config.reflectionEnabled) setPendingJournal(rec);
          sinceRef.current = null;
          setRun(null);
          snapshotNow(null, false);
          setFlash("Descanso terminado. Vuelve cuando quieras.");
          break;
        }
      }
    }, 250);
    return () => window.clearInterval(id);
  }, [active, config, effectiveElapsed, park, persist]);

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

  const start = useCallback(
    (mode: Mode, taskId: string | null = null) => {
      const now = new Date();
      baseRef.current = 0;
      sinceRef.current = now.getTime();
      setPending(null);
      setFlash(null);
      setPaused(false);
      setGhost(null);
      const r = startRun(mode, now.toISOString(), taskId, config);
      setRun(r);
      snapshotNow(r, false);
    },
    [snapshotNow],
  );

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
    const frozen = { ...prev, elapsedSec: baseRef.current };
    setRun(frozen);
    setPaused(true);
    snapshotNow(frozen, true);
  }, [effectiveElapsed, snapshotNow]);

  const resume = useCallback(() => {
    sinceRef.current = Date.now();
    setPaused(false);
    snapshotNow(runRef.current, false);
  }, [snapshotNow]);

  const stop = useCallback(() => {
    const prev = runRef.current;
    if (!prev) return;
    const record = stopEarly(
      { ...prev, elapsedSec: effectiveElapsed(prev) },
      new Date().toISOString(),
    );
    if (record) {
      persist(record);
      if (config.reflectionEnabled) setPendingJournal(record);
    }
    sinceRef.current = null;
    setPaused(false);
    setRun(null);
    snapshotNow(null, false);
  }, [effectiveElapsed, persist, snapshotNow]);

  const takeFlowBreak = useCallback(() => {
    const prev = runRef.current;
    if (!prev || prev.phase !== "flow") return;
    const flowSec = effectiveElapsed(prev);
    baseRef.current = 0;
    sinceRef.current = Date.now();
    const r = {
      ...prev,
      phase: "flowBreak" as const,
      elapsedSec: 0,
      targetSec: suggestedBreakSec(flowSec),
      flowSec,
    };
    setRun(r);
    snapshotNow(r, false);
  }, [effectiveElapsed, snapshotNow]);

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
      targetSec: config.pomodoroSec,
    });
  }, [park, config]);

  const retrySave = useCallback(() => {
    const rec = failedRecord;
    if (rec && persist(rec)) {
      setSaveError(false);
      setFailedRecord(null);
    }
  }, [failedRecord, persist]);

  const completeJournal = useCallback((rating: number | null, note: string) => {
    const pj = pendingJournal;
    if (pj && (rating != null || note.trim())) {
      if (!saveJournalEntry(pj.id, rating, note)) setSaveError(true);
    }
    setPendingJournal(null);
  }, [pendingJournal]);

  const skipJournal = useCallback(() => {
    setPendingJournal(null);
  }, []);

  const resumeGhost = useCallback(() => {
    const g = ghost;
    if (!g || runRef.current) return;
    const elapsed = elapsedAt(g.snapshot, Date.now());
    const r = { ...g.snapshot.run, elapsedSec: elapsed };
    baseRef.current = elapsed;
    sinceRef.current = g.snapshot.paused ? null : Date.now();
    setRun(r);
    setPaused(g.snapshot.paused);
    setGhost(null);
    snapshotNow(r, g.snapshot.paused);
  }, [ghost, snapshotNow]);

  const discardGhost = useCallback(() => {
    const g = ghost;
    if (!g) return;
    if (g.elapsedSec >= 60) {
      persist({
        id: `ghost-${Date.now()}`,
        mode: g.snapshot.run.mode,
        startedAtISO: g.snapshot.run.startedAtISO,
        durationSec: Math.round(g.elapsedSec),
        completed: false,
        taskId: g.snapshot.run.taskId ?? null,
      });
    }
    const storage = browserStorage();
    if (storage) clearActiveRun(storage);
    setGhost(null);
  }, [ghost, persist]);

  const suggestBreak =
    run?.mode === "flowtime" && run.phase === "flow" && run.elapsedSec >= DEFAULTS.flowMinSec;

  return {
    run,
    paused,
    pending,
    saveError,
    flash,
    suggestBreak,
    pendingJournal,
    start,
    startPending,
    pause,
    resume,
    stop,
    takeFlowBreak,
    skipBreak,
    retrySave,
    dismissFlash: () => setFlash(null),
    completeJournal,
    skipJournal,
    ghost,
    resumeGhost,
    discardGhost,
  };
}
