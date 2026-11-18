import { normalizeTask, type Energy, type Priority, type Task } from "../tasks/tasks";
import type { Mode, SessionRecord } from "../focus/engine";

/* Mappers local <-> contrato para POST /sync/initial-upload.
   Supuestos registrados (pendientes de refino contra iOS si difieren):
   - Task.finishDate = doneAtISO si está hecha, si no dueISO (fecha objetivo).
   - energyLevel usa los mismos strings del iPad (deep/shallow/admin).
   - mode timeBlock <-> timeblock (el contrato usa una palabra). */

export function priorityToServer(p: Priority): number {
  switch (p) {
    case "low": return 1;
    case "medium": return 2;
    case "high": return 3;
    default: return 0;
  }
}

export function priorityFromServer(n: unknown): Priority {
  switch (n) {
    case 1: return "low";
    case 2: return "medium";
    case 3: return "high";
    default: return "none";
  }
}

export function energyFromServer(v: unknown): Energy {
  return v === "deep" || v === "shallow" || v === "admin" ? v : "deep";
}

export function modeToServer(mode: Mode): string {
  return mode === "timeBlock" ? "timeblock" : mode;
}

export function modeFromServer(mode: unknown): Mode {
  if (mode === "timeblock") return "timeBlock";
  if (mode === "pomodoro" || mode === "flowtime" || mode === "stopwatch") return mode;
  return "pomodoro";
}

export interface ServerTask {
  syncId?: unknown;
  title?: unknown;
  description?: unknown;
  energyLevel?: unknown;
  recurrenceRule?: unknown;
  createdDate?: unknown;
  finishDate?: unknown;
  isFinished?: unknown;
  priority?: unknown;
  completedPomodoros?: unknown;
  updatedAt?: unknown;
  subTasks?: unknown;
}

export function taskToServer(t: Task, nowISO: string): Record<string, unknown> {
  return {
    syncId: t.id,
    title: t.title,
    description: t.notes || null,
    energyLevel: t.energy,
    recurrenceRule: t.recurrence,
    createdDate: t.createdAtISO,
    finishDate: t.doneAtISO ?? t.dueISO,
    isFinished: t.done,
    priority: priorityToServer(t.priority),
    estimatedPomodoros: 0,
    completedPomodoros: t.pomodoros,
    updatedAt: nowISO,
    subTasks: t.subtasks.map((s) => ({ title: s.title, isFinished: s.done })),
  };
}

export function taskFromServer(s: ServerTask): Task | null {
  if (typeof s.syncId !== "string" || typeof s.title !== "string") return null;
  const subs = Array.isArray(s.subTasks) ? s.subTasks : [];
  return normalizeTask({
    id: s.syncId,
    title: s.title,
    notes: typeof s.description === "string" ? s.description : "",
    done: s.isFinished === true,
    doneAtISO: typeof s.finishDate === "string" ? s.finishDate : null,
    priority: priorityFromServer(s.priority),
    energy: energyFromServer(s.energyLevel),
    pomodoros: typeof s.completedPomodoros === "number" ? s.completedPomodoros : 0,
    today: false,
    dueISO: typeof s.finishDate === "string" ? s.finishDate : null,
    recurrence: typeof s.recurrenceRule === "string" ? s.recurrenceRule : null,
    subtasks: subs
      .filter((x): x is { title: string; isFinished?: unknown } => typeof (x as { title?: unknown })?.title === "string")
      .map((x, i) => ({ id: `${s.syncId}-s${i}`, title: x.title, done: x.isFinished === true })),
    createdAtISO: typeof s.createdDate === "string" ? s.createdDate : new Date().toISOString(),
    order: 0,
  });
}

export interface ServerSession {
  id?: unknown;
  mode?: unknown;
  taskSyncId?: unknown;
  startedAt?: unknown;
  durationSeconds?: unknown;
  elapsedSeconds?: unknown;
  wasCompleted?: unknown;
}

export function sessionToServer(s: SessionRecord, nowISO: string): Record<string, unknown> {
  const ended = new Date(new Date(s.startedAtISO).getTime() + s.durationSec * 1000).toISOString();
  const countdown = s.mode === "pomodoro" || s.mode === "timeBlock";
  return {
    id: s.id,
    mode: modeToServer(s.mode),
    taskSyncId: s.taskId,
    phase: countdown ? "work" : "freeform",
    startedAt: s.startedAtISO,
    endedAt: ended,
    durationSeconds: Math.round(s.durationSec),
    elapsedSeconds: Math.round(s.durationSec),
    pauseCount: 0,
    totalPauseSeconds: 0,
    wasCompleted: s.completed,
    createdAt: nowISO,
    updatedAt: nowISO,
  };
}

export function sessionFromServer(s: ServerSession): SessionRecord | null {
  if (typeof s.startedAt !== "string") return null;
  const duration =
    typeof s.durationSeconds === "number" ? s.durationSeconds
    : typeof s.elapsedSeconds === "number" ? s.elapsedSeconds
    : 0;
  return {
    id: typeof s.id === "string" ? s.id : `srv-${Date.now()}`,
    mode: modeFromServer(s.mode),
    startedAtISO: s.startedAt,
    durationSec: duration,
    completed: s.wasCompleted === true,
    taskId: typeof s.taskSyncId === "string" ? s.taskSyncId : null,
  };
}

/** Adopt the canonical server lists after initial-upload (server wins). */
export function adoptTasks(server: unknown[]): Task[] {
  if (!Array.isArray(server)) return [];
  return (server as ServerTask[])
    .map((s) => taskFromServer(s))
    .filter((t): t is Task => t !== null)
    .map((t, i) => ({ ...t, order: i + 1 }));
}

export function adoptSessions(server: unknown[]): import("../focus/engine").SessionRecord[] {
  if (!Array.isArray(server)) return [];
  return (server as ServerSession[])
    .map((s) => sessionFromServer(s))
    .filter((s): s is import("../focus/engine").SessionRecord => s !== null);
}

const DEVICE_KEY = "pepinillo:device-id";

export function getDeviceId(): string {
  try {
    const existing = localStorage.getItem(DEVICE_KEY);
    if (existing) return existing;
    const fresh =
      typeof crypto !== "undefined" && "randomUUID" in crypto
        ? crypto.randomUUID()
        : `web-${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    localStorage.setItem(DEVICE_KEY, fresh);
    return fresh;
  } catch {
    return `web-${Date.now()}-nodb`;
  }
}
