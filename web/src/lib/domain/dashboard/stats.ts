/**
 * Dashboard stats — local-time aggregation over terminal session records.
 * Composes daily.ts primitives. Focus score formula is documented and
 * test-locked: consistency (active days / 7) 60%, volume (weekly focus
 * minutes vs 300) 25%, completion rate 15%.
 */

import type { FocusMode, FocusSession } from '$lib/domain/entities/types';
import { buildDailyStats, computeBestStreak, computeStreak, lastNDays, type DailyStat } from '$lib/domain/stats/daily';
import { isWorkPhase } from '$lib/domain/stats/daily';
import { localDateKey } from '$lib/domain/tasks/recurrence';

export type AnalyticsPeriod = 7 | 30 | 365;

export interface ModeBreakdown {
	mode: FocusMode;
	seconds: number;
	count: number;
}

export interface DashboardStats {
	todayFocusSeconds: number;
	todaySessions: number;
	periodFocusSeconds: number;
	periodSessions: number;
	weekly: DailyStat[];
	streak: number;
	bestStreak: number;
	modeBreakdown: ModeBreakdown[];
	focusScore: number;
	focusScoreQualifier: 'exceptional' | 'strong' | 'steady' | 'warming' | 'rest';
	peakHour: number | null;
	bestDay: number | null; // 0=Sunday … 6=Saturday
	completionRate: number; // 0..1 work sessions completed
	longestSessionMs: number;
}

const FREE_GOAL_WEEKLY_MINUTES = 300; // ~43 min/day — transparent baseline

export function computeDashboardStats(
	sessions: FocusSession[],
	now: Date = new Date(),
	period: AnalyticsPeriod = 7
): DashboardStats {
	const terminal = sessions.filter(
		(s) => (s.status === 'completed' || s.status === 'skipped') && s.startedAt && isWorkPhase(s.phase)
	);
	const stats = buildDailyStats(terminal, now);
	const weekly = lastNDays(stats, 7, now);

	const todayKey = localDateKey(now);
	const today = stats.find((d) => d.date === todayKey);
	const periodStart = new Date(now);
	periodStart.setDate(periodStart.getDate() - (period - 1));
	const periodKey = localDateKey(periodStart);
	const inPeriod = terminal.filter((s) => {
		const key = localDateKey(new Date(s.startedAt!));
		return key >= periodKey && key <= todayKey;
	});

	const periodSeconds = inPeriod.reduce((acc, s) => acc + Math.round(s.elapsedMs / 1000), 0);
	const completed = inPeriod.filter((s) => s.status === 'completed');

	// Mode breakdown within the period.
	const byMode = new Map<FocusMode, ModeBreakdown>();
	for (const s of inPeriod) {
		const entry = byMode.get(s.mode) ?? { mode: s.mode, seconds: 0, count: 0 };
		entry.seconds += Math.round(s.elapsedMs / 1000);
		if (s.status === 'completed') entry.count += 1;
		byMode.set(s.mode, entry);
	}
	const modeBreakdown = [...byMode.values()].sort((a, b) => b.seconds - a.seconds);

	// Patterns: peak hour and best weekday (local, over the whole history).
	const hourTotals = new Array(24).fill(0) as number[];
	const dayTotals = new Array(7).fill(0) as number[];
	for (const s of terminal) {
		const d = new Date(s.startedAt!);
		const secs = Math.round(s.elapsedMs / 1000);
		hourTotals[d.getHours()] += secs;
		dayTotals[d.getDay()] += secs;
	}
	const peakHour = argMax(hourTotals);
	const bestDay = argMax(dayTotals);

	const terminalWork = inPeriod.length;
	const completionRate = terminalWork > 0 ? completed.length / terminalWork : 0;
	const longestSessionMs = inPeriod.reduce((acc, s) => Math.max(acc, s.elapsedMs), 0);

	const weeklyMinutes = weekly.reduce((acc, d) => acc + d.totalFocusSeconds / 60, 0);
	const activeDays = weekly.filter((d) => d.totalFocusSeconds > 0).length;
	const focusScore = Math.round(
		Math.min(100, 60 * (activeDays / 7) + 25 * Math.min(1, weeklyMinutes / FREE_GOAL_WEEKLY_MINUTES) + 15 * completionRate)
	);

	return {
		todayFocusSeconds: today?.totalFocusSeconds ?? 0,
		todaySessions: today?.sessionsCompleted ?? 0,
		periodFocusSeconds: periodSeconds,
		periodSessions: completed.length,
		weekly,
		streak: computeStreak(stats, now),
		bestStreak: computeBestStreak(stats),
		modeBreakdown,
		focusScore,
		focusScoreQualifier: qualifierFor(focusScore),
		peakHour,
		bestDay,
		completionRate,
		longestSessionMs
	};
}

function qualifierFor(score: number): DashboardStats['focusScoreQualifier'] {
	if (score >= 85) return 'exceptional';
	if (score >= 70) return 'strong';
	if (score >= 50) return 'steady';
	if (score >= 30) return 'warming';
	return 'rest';
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
