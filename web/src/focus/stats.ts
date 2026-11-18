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

export interface DayPoint {
  day: string;
  minutes: number;
  sessions: number;
}

/** Last `days` days ending today, oldest first, zeros included. */
export function perDaySeries(sessions: SessionRecord[], days: number, now: Date): DayPoint[] {
  const map = new Map<string, { min: number; n: number }>();
  for (const s of sessions) {
    const day = dayKey(new Date(s.startedAtISO));
    const cur = map.get(day) ?? { min: 0, n: 0 };
    cur.min += s.durationSec / 60;
    cur.n += 1;
    map.set(day, cur);
  }
  const out: DayPoint[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    const key = dayKey(d);
    const cur = map.get(key);
    out.push({ day: key, minutes: Math.round(cur?.min ?? 0), sessions: cur?.n ?? 0 });
  }
  return out;
}

export interface RangeSummary {
  sessions: number;
  completed: number;
  focusMin: number;
  activeDays: number;
  perMode: Record<SessionRecord["mode"], number>;
}

export function summarizeRange(sessions: SessionRecord[], fromISO: string, toISO: string): RangeSummary {
  const perMode: Record<SessionRecord["mode"], number> = {
    pomodoro: 0,
    flowtime: 0,
    timeBlock: 0,
    stopwatch: 0,
  };
  const days = new Set<string>();
  let sec = 0;
  let completed = 0;
  let count = 0;
  for (const s of sessions) {
    if (s.startedAtISO < fromISO || s.startedAtISO >= toISO) continue;
    count += 1;
    sec += s.durationSec;
    if (s.completed) completed += 1;
    perMode[s.mode] += s.durationSec / 60;
    days.add(dayKey(new Date(s.startedAtISO)));
  }
  const rounded = { pomodoro: 0, flowtime: 0, timeBlock: 0, stopwatch: 0 } as RangeSummary["perMode"];
  for (const m of Object.keys(perMode) as (keyof typeof perMode)[]) {
    rounded[m] = Math.round(perMode[m]);
  }
  return { sessions: count, completed, focusMin: Math.round(sec / 60), activeDays: days.size, perMode: rounded };
}

/** Percent change vs the previous period. Null when there is no baseline. */
export function trendPct(current: number, previous: number): number | null {
  if (previous <= 0) return null;
  return Math.round(((current - previous) / previous) * 100);
}

export interface Achievement {
  id: string;
  name: string;
  detail: string;
  earned: boolean;
}

export function achievements(
  sessions: SessionRecord[],
  tasksDone: number,
  now: Date,
): Achievement[] {
  void tasksDone;
  const total = sessions.length;
  const best = bestDayMinutes(sessions);
  const streak = streakDays(sessions, now);
  const days = new Set(sessions.map((s) => dayKey(new Date(s.startedAtISO)))).size;
  return [
    { id: "first", name: "Primera sesión", detail: "Completa tu primer enfoque", earned: total >= 1 },
    { id: "streak3", name: "Racha de 3", detail: "3 días seguidos con enfoque", earned: streak >= 3 },
    { id: "streak7", name: "Semana completa", detail: "7 días seguidos con enfoque", earned: streak >= 7 },
    { id: "marathon", name: "Maratón", detail: "120 min de enfoque en un día", earned: (best?.minutes ?? 0) >= 120 },
    { id: "century", name: "Centena", detail: "100 sesiones de enfoque", earned: total >= 100 },
    { id: "steady", name: "Constancia", detail: "30 días distintos con enfoque", earned: days >= 30 },
  ];
}

export interface TaskSlice {
  taskId: string;
  sessions: number;
  minutes: number;
}

/** Focus minutes per linked task, best first. Unlinked sessions are skipped. */
export function taskBreakdown(sessions: SessionRecord[]): TaskSlice[] {
  const map = new Map<string, { n: number; min: number }>();
  for (const s of sessions) {
    if (!s.taskId) continue;
    const cur = map.get(s.taskId) ?? { n: 0, min: 0 };
    cur.n += 1;
    cur.min += s.durationSec / 60;
    map.set(s.taskId, cur);
  }
  return [...map.entries()]
    .map(([taskId, v]) => ({ taskId, sessions: v.n, minutes: Math.round(v.min) }))
    .sort((a, b) => b.minutes - a.minutes);
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
