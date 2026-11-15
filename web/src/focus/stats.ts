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

/** Best single-day focus minutes across the whole journal. */
export function bestDayMinutes(sessions: SessionRecord[]): { day: string; minutes: number } | null {
  const perDay = new Map<string, number>();
  for (const s of sessions) {
    const day = dayKey(new Date(s.startedAtISO));
    perDay.set(day, (perDay.get(day) ?? 0) + s.durationSec);
  }
  let best: { day: string; minutes: number } | null = null;
  for (const [day, sec] of perDay) {
    const minutes = Math.round(sec / 60);
    if (!best || minutes > best.minutes) best = { day, minutes };
  }
  return best;
}

export interface ModeTip {
  mode: SessionRecord["mode"];
  rate: number;
  sessions: number;
}

/** Mode with the best completion rate (min 2 sessions ≥60 s). Null when
    there isn't enough history — the UI then stays quiet, no generic tip. */
export function suggestBestMode(sessions: SessionRecord[]): ModeTip | null {
  const byMode = new Map<SessionRecord["mode"], { total: number; done: number }>();
  for (const s of sessions) {
    if (s.durationSec < 60) continue;
    const cur = byMode.get(s.mode) ?? { total: 0, done: 0 };
    cur.total += 1;
    if (s.completed) cur.done += 1;
    byMode.set(s.mode, cur);
  }
  let tip: ModeTip | null = null;
  for (const [mode, { total, done }] of byMode) {
    if (total < 2) continue;
    const rate = done / total;
    if (!tip || rate > tip.rate || (rate === tip.rate && total > tip.sessions)) {
      tip = { mode, rate, sessions: total };
    }
  }
  return tip;
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
