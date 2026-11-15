import { useState } from "react";

/* Tasks store — mirrors TaskItemState + filters
   (ios/Features/Tasks/TaskListFeature.swift:53, ios/Domain/Models/TaskItem.swift).
   Subset honesto: título, notas, hecho, prioridad, energía, pomodoros,
   hoy, orden. Subtareas y recurrencia llegan después. */

export type Energy = "deep" | "shallow" | "admin";
export type Priority = "none" | "low" | "medium" | "high";

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
  createdAtISO: string;
  order: number;
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
    return (parsed as Task[]).filter((t) => typeof t?.id === "string" && typeof t?.title === "string");
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
    retry: () => commit(tasks),
  };
}
