import type { SessionRecord } from "./engine";

/* Dashboard stats from the local session journal (useFocus persists it).
   Pure functions so the rules are testable. */

export function dayKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export interface TodaySummary {
  sessions: number;
  completed: number;
  focusMin: number;
}

export function summarizeToday(sessions: SessionRecord[], now: Date): TodaySummary {
  const key = dayKey(now);
  const mine = sessions.filter((s) => dayKey(new Date(s.startedAtISO)) === key);
  return {
    sessions: mine.length,
    completed: mine.filter((s) => s.completed).length,
    focusMin: Math.round(mine.reduce((m, s) => m + s.durationSec, 0) / 60),
  };
}

/** Consecutive active days ending today (or yesterday, so the streak
    survives until tonight). A day counts with >= 1 session of 60 s+. */
export function streakDays(sessions: SessionRecord[], now: Date): number {
  const active = new Set<string>();
  for (const s of sessions) {
    if (s.durationSec >= 60) active.add(dayKey(new Date(s.startedAtISO)));
  }
  let streak = 0;
  const cursor = new Date(now);
  if (!active.has(dayKey(cursor))) cursor.setDate(cursor.getDate() - 1);
  while (active.has(dayKey(cursor))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}
