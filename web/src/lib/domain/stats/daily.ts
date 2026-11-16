/**
 * Daily stats aggregation — mirror of DailyStats (iOS) / DailyStatsEntity
 * (Android), fed by completed/skipped-with-credit session records.
 * Pure and local-time based (the apps aggregate in device local time).
 */

import type { FocusMode, FocusPhase, FocusSession } from '$lib/domain/entities/types';

export interface DailyStat {
	/** Local calendar day key: YYYY-MM-DD. */
	date: string;
	totalFocusSeconds: number;
	sessionsCompleted: number;
	byModeSeconds: Record<FocusMode, number>;
	byModeCount: Record<FocusMode, number>;
}

export function dateKey(d: Date): string {
	const y = d.getFullYear();
	const m = String(d.getMonth() + 1).padStart(2, '0');
	const day = String(d.getDate()).padStart(2, '0');
	return `${y}-${m}-${day}`;
}

function emptyStat(date: string): DailyStat {
	return {
		date,
		totalFocusSeconds: 0,
		sessionsCompleted: 0,
		byModeSeconds: { pomodoro: 0, flowtime: 0, timeblock: 0, stopwatch: 0 },
		byModeCount: { pomodoro: 0, flowtime: 0, timeblock: 0, stopwatch: 0 }
	};
}

/** Work sessions carry focus time; breaks do not. */
export function isWorkPhase(phase: FocusPhase | undefined): boolean {
	return phase === undefined || phase === 'work';
}

/** A session counts toward `sessionsCompleted` when fully completed. */
export function countsAsCompleted(s: FocusSession): boolean {
	return s.status === 'completed';
}

export function foldSessionIntoStat(stat: DailyStat, s: FocusSession): DailyStat {
	if (!isWorkPhase(s.phase)) return stat;
	const seconds = Math.max(0, Math.round(s.elapsedMs / 1000));
	const mode = s.mode;
	const next: DailyStat = {
		...stat,
		totalFocusSeconds: stat.totalFocusSeconds + seconds,
		byModeSeconds: { ...stat.byModeSeconds, [mode]: stat.byModeSeconds[mode] + seconds },
		byModeCount: { ...stat.byModeCount }
	};
	if (countsAsCompleted(s)) {
		next.sessionsCompleted += 1;
		next.byModeCount[mode] += 1;
	}
	return next;
}

/** Aggregate terminal sessions (completed / skipped) into daily stats. */
export function buildDailyStats(sessions: FocusSession[], today: Date = new Date()): DailyStat[] {
	const byDate = new Map<string, DailyStat>();
	for (const s of sessions) {
		if (s.status !== 'completed' && s.status !== 'skipped') continue;
		if (!s.startedAt) continue;
		const key = dateKey(new Date(s.startedAt));
		const stat = byDate.get(key) ?? emptyStat(key);
		byDate.set(key, foldSessionIntoStat(stat, s));
	}
	return [...byDate.values()].sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Current streak: consecutive days with ≥1 counted session, ending today;
 * a streak survives if the last focus day was yesterday (today still open).
 */
export function computeStreak(stats: DailyStat[], today: Date = new Date()): number {
	const active = new Set(stats.filter((d) => d.totalFocusSeconds > 0).map((d) => d.date));
	if (active.size === 0) return 0;

	const cursor = new Date(today);
	if (!active.has(dateKey(cursor))) {
		cursor.setDate(cursor.getDate() - 1);
		if (!active.has(dateKey(cursor))) return 0;
	}
	let streak = 0;
	while (active.has(dateKey(cursor))) {
		streak += 1;
		cursor.setDate(cursor.getDate() - 1);
	}
	return streak;
}

/** Best (longest) streak in the observed history. */
export function computeBestStreak(stats: DailyStat[]): number {
	let best = 0;
	let run = 0;
	let prev: string | null = null;
	for (const d of stats) {
		if (d.totalFocusSeconds <= 0) {
			run = 0;
			prev = null;
			continue;
		}
		if (prev && nextDayKey(prev) === d.date) {
			run += 1;
		} else {
			run = 1;
		}
		prev = d.date;
		best = Math.max(best, run);
	}
	return best;
}

function nextDayKey(key: string): string {
	const [y, m, d] = key.split('-').map(Number);
	const date = new Date(y, m - 1, d);
	date.setDate(date.getDate() + 1);
	return dateKey(date);
}

/** Focus time of the last N local days including empty days (chart-ready). */
export function lastNDays(stats: DailyStat[], n: number, today: Date = new Date()): DailyStat[] {
	const byDate = new Map(stats.map((d) => [d.date, d]));
	const out: DailyStat[] = [];
	const cursor = new Date(today);
	cursor.setDate(cursor.getDate() - (n - 1));
	for (let i = 0; i < n; i += 1) {
		const key = dateKey(cursor);
		out.push(byDate.get(key) ?? emptyStat(key));
		cursor.setDate(cursor.getDate() + 1);
	}
	return out;
}
