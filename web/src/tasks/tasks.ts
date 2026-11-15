import { useState } from "react";

/* Tasks store — mirrors TaskItemState + filters
   (ios/Features/Tasks/TaskListFeature.swift:53, ios/Domain/Models/TaskItem.swift).
   Subset honesto: título, notas, hecho, prioridad, energía, pomodoros,
   hoy, orden. Subtareas y recurrencia llegan después. */

export type Energy = "deep" | "shallow" | "admin";
export type Priority = "none" | "low" | "medium" | "high";

export interface Subtask {
  id: string;
  title: string;
  done: boolean;
}

export interface Task {
  id: string;
  title: string;
  notes: string;
  done: boolean;
  doneAtISO: string | null;
  priority: Priority;
  energy: Energy;
  pomodoros: number;
  today: boolean;
  dueISO: string | null;
  recurrence: string | null;
  subtasks: Subtask[];
  createdAtISO: string;
  order: number;
}

export type TaskScope = "today" | "inbox" | "upcoming" | "done";

/** Fill defaults for tasks stored before these fields existed. */
export function normalizeTask(raw: Partial<Task> & { id: string; title: string }): Task {
  return {
    notes: "",
    done: false,
    doneAtISO: null,
    priority: "none",
    energy: "deep",
    pomodoros: 0,
    today: true,
    dueISO: null,
    recurrence: null,
    subtasks: [],
    createdAtISO: new Date().toISOString(),
    order: 0,
    ...raw,
    id: raw.id,
    title: raw.title,
  };
}

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

export const TASKS_KEY = "pepinillo:tasks.v1";

export const ENERGY_LABEL: Record<Energy, string> = {
  deep: "Profunda",
  shallow: "Ligera",
  admin: "Admin",
};

export const PRIORITY_LABEL: Record<Priority, string> = {
  none: "Ninguna",
  low: "Baja",
  medium: "Media",
  high: "Alta",
};

/** Same table as EnergySuggestion.suggestedLevel (EnergySuggestion.swift:20). */
export function suggestedEnergyForHour(hour: number): Energy {
  if (hour >= 6 && hour < 11) return "deep";
  if (hour >= 11 && hour < 13) return "shallow";
  if (hour >= 13 && hour < 15) return "admin";
  if (hour >= 15 && hour < 18) return "deep";
  if (hour >= 18 && hour < 21) return "shallow";
  return "admin";
}

export function parseTasks(raw: string | null): Task[] {
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return (parsed as Partial<Task>[])
      .filter((t) => typeof t?.id === "string" && typeof t?.title === "string")
      .map((t) => normalizeTask(t as Partial<Task> & { id: string; title: string }));
  } catch {
    return [];
  }
}

let seq = 0;
export function addTask(
  tasks: Task[],
  input: { title: string; energy: Energy; priority: Priority; today: boolean },
  nowISO: string,
): Task[] {
  const title = input.title.trim();
  if (!title) return tasks;
  seq += 1;
  const maxOrder = tasks.reduce((m, t) => Math.max(m, t.order), 0);
  return [
    ...tasks,
    {
      id: `${Date.now()}-${seq}-${Math.floor(Math.random() * 1e6)}`,
      title,
      notes: "",
      done: false,
      doneAtISO: null,
      priority: input.priority,
      energy: input.energy,
      pomodoros: 0,
      today: input.today,
      dueISO: null,
      recurrence: null,
      subtasks: [],
      createdAtISO: nowISO,
      order: maxOrder + 1,
    },
  ];
}

export function toggleTask(tasks: Task[], id: string, nowISO: string): Task[] {
  return tasks.map((t) =>
    t.id === id
      ? { ...t, done: !t.done, doneAtISO: !t.done ? nowISO : null }
      : t,
  );
}

export function removeTask(tasks: Task[], id: string): Task[] {
  return tasks.filter((t) => t.id !== id);
}

export function updateTask(tasks: Task[], id: string, patch: Partial<Task>): Task[] {
  return tasks.map((t) => (t.id === id ? { ...t, ...patch, id: t.id } : t));
}

let subSeq = 0;
export function addSubtask(tasks: Task[], id: string, title: string): Task[] {
  const clean = title.trim();
  if (!clean) return tasks;
  subSeq += 1;
  return tasks.map((t) =>
    t.id === id
      ? { ...t, subtasks: [...t.subtasks, { id: `${Date.now()}-s${subSeq}`, title: clean, done: false }] }
      : t,
  );
}

export function toggleSubtask(tasks: Task[], id: string, subId: string): Task[] {
  return tasks.map((t) =>
    t.id === id
      ? { ...t, subtasks: t.subtasks.map((s) => (s.id === subId ? { ...s, done: !s.done } : s)) }
      : t,
  );
}

export function removeSubtask(tasks: Task[], id: string, subId: string): Task[] {
  return tasks.map((t) =>
    t.id === id ? { ...t, subtasks: t.subtasks.filter((s) => s.id !== subId) } : t,
  );
}

/** Smart lists mirror PlanFilter (PlanFilter.swift): today / inbox / upcoming / done. */
export function filterTasks(tasks: Task[], scope: TaskScope, energy: Energy | "all"): Task[] {
  const now = new Date().toISOString().slice(0, 10);
  return sortForList(tasks).filter((t) => {
    if (energy !== "all" && t.energy !== energy) return false;
    switch (scope) {
      case "today":
        return (t.today || (t.dueISO != null && t.dueISO.slice(0, 10) <= now)) && !t.done;
      case "inbox":
        return !t.today && t.dueISO == null && !t.done;
      case "upcoming":
        return t.dueISO != null && t.dueISO.slice(0, 10) > now && !t.done;
      case "done":
        return t.done;
    }
  });
}

/** Open tasks first (manual order), done at the end. */
export function sortForList(tasks: Task[]): Task[] {
  return [...tasks].sort((a, b) => {
    if (a.done !== b.done) return a.done ? 1 : -1;
    return a.order - b.order;
  });
}

/** Returns false (never throws) so the view can warn visibly. */
export function saveTasks(storage: StorageLike, tasks: Task[]): boolean {
  try {
    storage.setItem(TASKS_KEY, JSON.stringify(tasks));
    return true;
  } catch {
    return false;
  }
}

function defaultStorage(): StorageLike {
  try {
    if (typeof localStorage !== "undefined") return localStorage;
  } catch {
    /* ignore: fall through to memory */
  }
  const mem = new Map<string, string>();
  return {
    getItem: (k) => mem.get(k) ?? null,
    setItem: (k, v) => void mem.set(k, v),
  };
}

export function useTasks(storage: StorageLike = defaultStorage()) {
  const [tasks, setTasks] = useState<Task[]>(() => {
    try {
      return parseTasks(storage.getItem(TASKS_KEY));
    } catch {
      return [];
    }
  });
  const [storeError, setStoreError] = useState(false);

  const commit = (next: Task[]): boolean => {
    // The in-memory list always moves forward; a failed write shows a
    // visible warning in the view instead of pretending it saved.
    const ok = saveTasks(storage, next);
    setTasks(next);
    setStoreError(!ok);
    return ok;
  };

  return {
    tasks,
    storeError,
    add: (input: { title: string; energy: Energy; priority: Priority; today: boolean }) =>
      commit(addTask(tasks, input, new Date().toISOString())),
    toggle: (id: string) => commit(toggleTask(tasks, id, new Date().toISOString())),
    remove: (id: string) => commit(removeTask(tasks, id)),
    update: (id: string, patch: Partial<Task>) => commit(updateTask(tasks, id, patch)),
    addSub: (id: string, title: string) => commit(addSubtask(tasks, id, title)),
    toggleSub: (id: string, subId: string) => commit(toggleSubtask(tasks, id, subId)),
    removeSub: (id: string, subId: string) => commit(removeSubtask(tasks, id, subId)),
    retry: () => commit(tasks),
  };
}
