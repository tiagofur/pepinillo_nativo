/**
 * Period reviews — mirror of WeeklyReviewView / WeeklyReviewSheet:
 * delta vs previous period, dominant mode, best day, mode distribution,
 * top tasks, trend.
 */

import type { FocusMode, FocusSession, Task } from '$lib/domain/entities/types';
import { isWorkPhase } from '$lib/domain/stats/daily';
import { localDateKey } from '$lib/domain/tasks/recurrence';

export type Trend = 'up' | 'down' | 'flat';

export interface ReviewTaskLine {
	taskId: string;
	title: string;
	sessions: number;
	seconds: number;
}

export interface PeriodReview {
	/** Inclusive window [periodStart, today], local days. */
	days: number;
	focusSeconds: number;
	sessionsCompleted: number;
	previousFocusSeconds: number;
	trend: Trend;
	trendPct: number; // 0..1 relative change vs previous
	dominantMode: FocusMode | null;
	bestDay: number | null; // 0=Sunday…6=Saturday (local weekday)
	modeDistribution: { mode: FocusMode; seconds: number; pct: number }[];
	topTasks: ReviewTaskLine[];
	streakDays: number;
	longestSessionMs: number;
}

const DAY_MS = 86_400_000;

export function buildPeriodReview(
	sessions: FocusSession[],
	tasks: Task[],
	now: Date = new Date(),
	days: 7 | 30 = 7
): PeriodReview {
	const work = sessions.filter(
		(s) => (s.status === 'completed' || s.status === 'skipped') && s.startedAt && isWorkPhase(s.phase)
	);
	const today = startOfDay(now);
	const periodStart = new Date(today.getTime() - (days - 1) * DAY_MS);
	const prevStart = new Date(periodStart.getTime() - days * DAY_MS);
	// The previous period is the `days` days before the current one:
	// [prevStart, periodStart-1ms] (i.e., the complete day before the window).
	const prevEnd = new Date(periodStart.getTime() - 1);

	const inWindow = work.filter((s) => {
		const t = new Date(s.startedAt!).getTime();
		return t >= periodStart.getTime();
	});
	const inPeriod = work.filter((s) => {
		const t = new Date(s.startedAt!).getTime();
		return t >= periodStart.getTime() && t <= today.getTime() + DAY_MS - 1;
	});
	const inPrev = work.filter((s) => {
		const t = new Date(s.startedAt!).getTime();
		return t >= prevStart.getTime() && t <= prevEnd.getTime();
	});

	const periodSeconds = sumSeconds(inPeriod);
	const prevSeconds = sumSeconds(inPrev);
	const completed = inPeriod.filter((s) => s.status === 'completed');

	// Mode distribution.
	const byMode = new Map<FocusMode, number>();
	for (const s of completed) {
		byMode.set(s.mode, (byMode.get(s.mode) ?? 0) + Math.round(s.elapsedMs / 1000));
	}
	const totalModeSeconds = [...byMode.values()].reduce((a, b) => a + b, 0);
	const modeDistribution = [...byMode.entries()]
		.map(([mode, seconds]) => ({
			mode,
			seconds,
			pct: totalModeSeconds > 0 ? seconds / totalModeSeconds : 0
		}))
		.sort((a, b) => b.seconds - a.seconds);

	// Best weekday within the period.
	const dayTotals = new Array(7).fill(0) as number[];
	for (const s of completed) {
		dayTotals[new Date(s.startedAt!).getDay()] += Math.round(s.elapsedMs / 1000);
	}
	const bestDay = argMax(dayTotals);

	// Top tasks by linked completed sessions.
	const taskAgg = new Map<string, { sessions: number; seconds: number }>();
	for (const s of completed) {
		if (!s.taskId) continue;
		const e = taskAgg.get(s.taskId) ?? { sessions: 0, seconds: 0 };
		e.sessions += 1;
		e.seconds += Math.round(s.elapsedMs / 1000);
		taskAgg.set(s.taskId, e);
	}
	const topTasks: ReviewTaskLine[] = [...taskAgg.entries()]
		.map(([taskId, agg]) => ({
			taskId,
			title: tasks.find((t) => t.id === taskId)?.title ?? taskId,
			...agg
		}))
		.sort((a, b) => b.sessions - a.sessions || b.seconds - a.seconds)
		.slice(0, 3);

	const delta = periodSeconds - prevSeconds;
	const trend: Trend = prevSeconds === 0 ? (periodSeconds > 0 ? 'up' : 'flat') : delta === 0 ? 'flat' : delta > 0 ? 'up' : 'down';
	const trendPct = prevSeconds > 0 ? Math.abs(delta) / prevSeconds : periodSeconds > 0 ? 1 : 0;

	// Streak at the end of the window.
	let streakDays = 0;
	const cursor = new Date(today);
	while (true) {
		const key = localDateKey(cursor);
		const daySeconds = completed.reduce((acc, s) => {
			return localDateKey(new Date(s.startedAt!)) === key ? acc + Math.round(s.elapsedMs / 1000) : acc;
		}, 0);
		if (daySeconds > 0) {
			streakDays += 1;
			cursor.setDate(cursor.getDate() - 1);
		} else break;
	}

	return {
		days,
		focusSeconds: periodSeconds,
		sessionsCompleted: completed.length,
		previousFocusSeconds: prevSeconds,
		trend,
		trendPct,
		dominantMode: modeDistribution[0]?.mode ?? null,
		bestDay,
		modeDistribution,
		topTasks,
		streakDays,
		longestSessionMs: inPeriod.reduce((acc, s) => Math.max(acc, s.elapsedMs), 0)
	};
}

function sumSeconds(sessions: FocusSession[]): number {
	return sessions.reduce((acc, s) => acc + Math.round(s.elapsedMs / 1000), 0);
}

function startOfDay(d: Date): Date {
	return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function argMax(values: number[]): number | null {
	let best = -1;
	let bestIdx: number | null = null;
	values.forEach((v, i) => {
		if (v > best) {
			best = v;
			bestIdx = i;
		}
	});
	return best > 0 ? bestIdx : null;
}
