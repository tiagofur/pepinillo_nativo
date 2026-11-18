import { describe, expect, it } from "vitest";
import {
  TASKS_KEY,
  addSubtask,
  addTask,
  filterTasks,
  normalizeTask,
  parseTasks,
  removeSubtask,
  removeTask,
  saveTasks,
  sortForList,
  suggestedEnergyForHour,
  toggleSubtask,
  toggleTask,
  updateTask,
  type StorageLike,
  type Task,
} from "./tasks";

const ISO = "2026-11-15T10:00:00.000Z";

function seed(): Task[] {
  let tasks: Task[] = [];
  tasks = addTask(tasks, { title: "Escribir", energy: "deep", priority: "high", today: true }, ISO);
  tasks = addTask(tasks, { title: "Correo", energy: "admin", priority: "low", today: false }, ISO);
  return tasks;
}

describe("suggestedEnergyForHour (same table as the iPad)", () => {
  it.each([
    [6, "deep"],
    [10, "deep"],
    [11, "shallow"],
    [12, "shallow"],
    [13, "admin"],
    [14, "admin"],
    [15, "deep"],
    [17, "deep"],
    [18, "shallow"],
    [20, "shallow"],
    [21, "admin"],
    [2, "admin"],
  ] as const)("hour %i -> %s", (hour, expected) => {
    expect(suggestedEnergyForHour(hour)).toBe(expected);
  });
});

describe("pure list ops", () => {
  it("add ignores blank titles", () => {
    expect(addTask([], { title: "   ", energy: "deep", priority: "none", today: true }, ISO)).toEqual([]);
  });

  it("toggle flips done and stamps the date", () => {
    const tasks = seed();
    const done = toggleTask(tasks, tasks[0].id, ISO);
    expect(done[0].done).toBe(true);
    expect(done[0].doneAtISO).toBe(ISO);
    const undone = toggleTask(done, tasks[0].id, ISO);
    expect(undone[0].done).toBe(false);
    expect(undone[0].doneAtISO).toBeNull();
  });

  it("remove drops only the target", () => {
    const tasks = seed();
    const next = removeTask(tasks, tasks[0].id);
    expect(next).toHaveLength(1);
    expect(next[0].title).toBe("Correo");
  });

  it("done tasks sort last", () => {
    const tasks = seed();
    const done = toggleTask(tasks, tasks[0].id, ISO);
    const sorted = sortForList(done);
    expect(sorted[sorted.length - 1].done).toBe(true);
  });

  it("corrupt storage parses to an empty list without throwing", () => {
    expect(parseTasks("{nope")).toEqual([]);
    expect(parseTasks('"hola"')).toEqual([]);
    expect(parseTasks(null)).toEqual([]);
  });
});

describe("failing storage", () => {
  const throwing: StorageLike = {
    getItem: () => null,
    setItem: () => {
      throw new DOMException("Quota exceeded", "QuotaExceededError");
    },
  };
  const memory = (): StorageLike => {
    const mem = new Map<string, string>();
    return { getItem: (k) => mem.get(k) ?? null, setItem: (k, v) => void mem.set(k, v) };
  };

  it("a throwing setItem returns false instead of silently dropping the write", () => {
    expect(saveTasks(throwing, seed())).toBe(false);
  });

  it("a working store round-trips", () => {
    const store = memory();
    const tasks = seed();
    expect(saveTasks(store, tasks)).toBe(true);
    expect(parseTasks(store.getItem(TASKS_KEY))).toHaveLength(2);
  });
});

describe("detail", () => {
  it("normalizeTask fills defaults for legacy tasks", () => {
    const t = normalizeTask({ id: "x", title: "Vieja" });
    expect(t.subtasks).toEqual([]);
    expect(t.dueISO).toBeNull();
    expect(t.recurrence).toBeNull();
    expect(t.notes).toBe("");
  });

  it("subtask add/toggle/remove", () => {
    const tasks = seed();
    const id = tasks[0].id;
    expect(addSubtask(tasks, id, "   ")).toHaveLength(2);
    const added = addSubtask(tasks, id, "Paso 1");
    expect(added[0].subtasks).toHaveLength(1);
    const subId = added[0].subtasks[0].id;
    const toggled = toggleSubtask(added, id, subId);
    expect(toggled[0].subtasks[0].done).toBe(true);
    expect(removeSubtask(toggled, id, subId)[0].subtasks).toHaveLength(0);
  });

  it("updateTask patches without touching the id", () => {
    const tasks = seed();
    const next = updateTask(tasks, tasks[0].id, { notes: "hola", dueISO: "2030-01-01", id: "hack" });
    expect(next[0].notes).toBe("hola");
    expect(next[0].dueISO).toBe("2030-01-01");
    expect(next[0].id).toBe(tasks[0].id);
  });
});

describe("smart lists", () => {
  it("routes tasks to today/inbox/upcoming/done", () => {
    const base = seed(); // Escribir(today), Correo(!today, no due)
    const future = updateTask(base, base[1].id, { dueISO: "2030-05-05" });
    expect(filterTasks(future, "today", "all").map((t) => t.title)).toEqual(["Escribir"]);
    expect(filterTasks(updateTask(base, base[0].id, { today: false }), "inbox", "all").map((t) => t.title)).toEqual(["Escribir", "Correo"]);
    expect(filterTasks(future, "upcoming", "all").map((t) => t.title)).toEqual(["Correo"]);
    const done = toggleTask(base, base[0].id, ISO);
    expect(filterTasks(done, "done", "all").map((t) => t.title)).toEqual(["Escribir"]);
    expect(filterTasks(done, "today", "all")).toHaveLength(0);
  });
});
