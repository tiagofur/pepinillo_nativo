import { dayKey } from "../focus/stats";
import type { SessionRecord } from "../focus/engine";

/* Month grid builder for the calendar (weeks start Monday, like iPad).
   Pure data: minutes come from the journal, due counts from local tasks. */

export interface CalDay {
  key: string;
  dayNumber: number;
  inMonth: boolean;
  minutes: number;
  sessions: number;
  tasksDue: number;
}

export interface DueTask {
  dueISO: string | null;
  done: boolean;
}

export function buildMonth(
  year: number,
  month: number,
  sessions: SessionRecord[],
  tasks: DueTask[],
): CalDay[][] {
  const perDay = new Map<string, { min: number; n: number }>();
  for (const s of sessions) {
    const day = dayKey(new Date(s.startedAtISO));
    const cur = perDay.get(day) ?? { min: 0, n: 0 };
    cur.min += s.durationSec / 60;
    cur.n += 1;
    perDay.set(day, cur);
  }
  const due = new Map<string, number>();
  for (const t of tasks) {
    if (t.done || !t.dueISO) continue;
    const day = t.dueISO.slice(0, 10);
    due.set(day, (due.get(day) ?? 0) + 1);
  }
  const first = new Date(year, month, 1);
  const offset = (first.getDay() + 6) % 7; // Monday-first
  const weeks: CalDay[][] = [];
  for (let w = 0; w < 6; w++) {
    const week: CalDay[] = [];
    for (let d = 0; d < 7; d++) {
      const date = new Date(year, month, 1 - offset + w * 7 + d);
      const key = dayKey(date);
      const cur = perDay.get(key);
      week.push({
        key,
        dayNumber: date.getDate(),
        inMonth: date.getMonth() === month,
        minutes: Math.round(cur?.min ?? 0),
        sessions: cur?.n ?? 0,
        tasksDue: due.get(key) ?? 0,
      });
    }
    weeks.push(week);
  }
  return weeks;
}
