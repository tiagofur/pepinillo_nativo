import { describe, expect, it } from 'vitest';
import {
	buildDailyStats,
	computeBestStreak,
	computeStreak,
	dateKey,
	foldSessionIntoStat,
	lastNDays
} from '$lib/domain/stats/daily';
import type { FocusSession } from '$lib/domain/entities/types';

function session(partial: Partial<FocusSession>): FocusSession {
	return {
		id: partial.id ?? 's',
		mode: partial.mode ?? 'pomodoro',
		status: partial.status ?? 'completed',
		startedAt: partial.startedAt ?? '2026-11-16T09:00:00',
		elapsedMs: partial.elapsedMs ?? 25 * 60_000,
		segmentStartedAt: null,
		targetMs: null,
		taskId: null,
		journal: '',
		completedAt: partial.completedAt ?? null,
		createdAt: partial.startedAt ?? '2026-11-16T09:00:00',
		updatedAt: partial.updatedAt ?? '2026-11-16T09:25:00',
		phase: partial.phase,
		satisfactionRating: partial.satisfactionRating,
		interruptions: partial.interruptions,
		pauseCount: partial.pauseCount,
		totalPauseMs: partial.totalPauseMs
	};
}

describe('foldSessionIntoStat', () => {
	it('accumulates work sessions and completion counts', () => {
		let stat = {
			date: '2026-11-16',
			totalFocusSeconds: 0,
			sessionsCompleted: 0,
			byModeSeconds: { pomodoro: 0, flowtime: 0, timeblock: 0, stopwatch: 0 },
			byModeCount: { pomodoro: 0, flowtime: 0, timeblock: 0, stopwatch: 0 }
		};
		stat = foldSessionIntoStat(stat, session({ mode: 'pomodoro', elapsedMs: 25 * 60_000 }));
		stat = foldSessionIntoStat(
			stat,
			session({ mode: 'flowtime', elapsedMs: 40 * 60_000, status: 'skipped' })
		);
		expect(stat.totalFocusSeconds).toBe(65 * 60);
		expect(stat.sessionsCompleted).toBe(1);
		expect(stat.byModeSeconds.flowtime).toBe(40 * 60);
		expect(stat.byModeCount.flowtime).toBe(0); // skipped does not count as completed
	});

	it('ignores break phases', () => {
		const stat = {
			date: '2026-11-16',
			totalFocusSeconds: 0,
			sessionsCompleted: 0,
			byModeSeconds: { pomodoro: 0, flowtime: 0, timeblock: 0, stopwatch: 0 },
			byModeCount: { pomodoro: 0, flowtime: 0, timeblock: 0, stopwatch: 0 }
		};
		const out = foldSessionIntoStat(
			stat,
			session({ phase: 'shortBreak', elapsedMs: 5 * 60_000 })
		);
		expect(out.totalFocusSeconds).toBe(0);
	});
});

describe('buildDailyStats', () => {
	it('groups by local day of startedAt and sorts', () => {
		const stats = buildDailyStats([
			session({ startedAt: '2026-11-15T09:00:00', elapsedMs: 10 * 60_000 }),
			session({ startedAt: '2026-11-16T23:30:00', elapsedMs: 20 * 60_000 }),
			session({ startedAt: '2026-11-16T10:00:00', elapsedMs: 5 * 60_000 })
		]);
		expect(stats.map((d) => d.date)).toEqual(['2026-11-15', '2026-11-16']);
		expect(stats[1].totalFocusSeconds).toBe(25 * 60);
	});
});

describe('computeStreak', () => {
	const day = (d: string, secs: number) => ({
		date: d,
		totalFocusSeconds: secs,
		sessionsCompleted: 1,
		byModeSeconds: { pomodoro: secs, flowtime: 0, timeblock: 0, stopwatch: 0 },
		byModeCount: { pomodoro: 1, flowtime: 0, timeblock: 0, stopwatch: 0 }
	});

	it('counts consecutive days ending today', () => {
		const today = new Date(2026, 10, 16); // local Nov 16 2026
		const stats = [day('2026-11-14', 60), day('2026-11-15', 60), day('2026-11-16', 60)];
		expect(computeStreak(stats, today)).toBe(3);
	});

	it('survives when the last focus day was yesterday', () => {
		const today = new Date(2026, 10, 16);
		expect(computeStreak([day('2026-11-15', 60)], today)).toBe(1);
	});

	it('breaks when yesterday is empty', () => {
		const today = new Date(2026, 10, 16);
		expect(computeStreak([day('2026-11-13', 60)], today)).toBe(0);
	});

	it('ignores zero-focus days inside the window', () => {
		const today = new Date(2026, 10, 16);
		const stats = [day(dateKey(today), 0), day('2026-11-15', 60)];
		expect(computeStreak(stats, today)).toBe(1);
	});
});

describe('computeBestStreak', () => {
	const day = (d: string, secs: number) => ({
		date: d,
		totalFocusSeconds: secs,
		sessionsCompleted: 1,
		byModeSeconds: { pomodoro: secs, flowtime: 0, timeblock: 0, stopwatch: 0 },
		byModeCount: { pomodoro: 1, flowtime: 0, timeblock: 0, stopwatch: 0 }
	});

	it('tracks the longest run', () => {
		const stats = [day('2026-11-01', 60), day('2026-11-02', 60), day('2026-11-04', 60)];
		expect(computeBestStreak(stats)).toBe(2);
	});
});

describe('lastNDays', () => {
	it('fills empty days for the chart', () => {
		const today = new Date(2026, 10, 16);
		const days = lastNDays(
			[
				{
					date: '2026-11-16',
					totalFocusSeconds: 100,
					sessionsCompleted: 2,
					byModeSeconds: { pomodoro: 100, flowtime: 0, timeblock: 0, stopwatch: 0 },
					byModeCount: { pomodoro: 2, flowtime: 0, timeblock: 0, stopwatch: 0 }
				}
			],
			7,
			today
		);
		expect(days).toHaveLength(7);
		expect(days[0].date).toBe('2026-11-10');
		expect(days[6].totalFocusSeconds).toBe(100);
	});
});
