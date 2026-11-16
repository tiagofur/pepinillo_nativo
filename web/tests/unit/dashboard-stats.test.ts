import { describe, expect, it } from 'vitest';
import { computeDashboardStats } from '$lib/domain/dashboard/stats';
import { evaluateAchievements } from '$lib/domain/achievements/achievements';
import { buildPeriodReview } from '$lib/domain/reviews/reviews';
import type { FocusSession, Task } from '$lib/domain/entities/types';

const NOW = new Date(2026, 10, 16, 12, 0, 0); // Monday Nov 16 2026, local noon

function session(partial: Partial<FocusSession>): FocusSession {
	return {
		id: partial.id ?? 's',
		mode: partial.mode ?? 'pomodoro',
		status: partial.status ?? 'completed',
		startedAt: partial.startedAt ?? '2026-11-16T09:00:00',
		elapsedMs: partial.elapsedMs ?? 25 * 60_000,
		segmentStartedAt: null,
		targetMs: null,
		taskId: partial.taskId ?? null,
		journal: '',
		completedAt: null,
		createdAt: partial.startedAt ?? '2026-11-16T09:00:00',
		updatedAt: partial.updatedAt ?? '2026-11-16T09:25:00',
		phase: partial.phase
	};
}

describe('computeDashboardStats', () => {
	it('aggregates today and the period', () => {
		const sessions = [
			session({ startedAt: '2026-11-16T09:00:00', elapsedMs: 25 * 60_000 }),
			session({ startedAt: '2026-11-15T09:00:00', elapsedMs: 30 * 60_000 }),
			session({ startedAt: '2026-11-16T11:00:00', elapsedMs: 10 * 60_000, status: 'skipped' })
		];
		const stats = computeDashboardStats(sessions, NOW, 7);
		// Focus time includes partial (skipped) work; session counts do not.
		expect(stats.todayFocusSeconds).toBe(35 * 60);
		expect(stats.periodFocusSeconds).toBe(65 * 60);
		expect(stats.periodSessions).toBe(2);
		expect(stats.weekly).toHaveLength(7);
		expect(stats.weekly[6].totalFocusSeconds).toBe(35 * 60);
	});

	it('computes patterns, breakdown and completion rate', () => {
		const sessions = [
			session({ startedAt: '2026-11-10T08:00:00', elapsedMs: 30 * 60_000 }),
			session({ startedAt: '2026-11-10T08:30:00', mode: 'stopwatch', elapsedMs: 20 * 60_000 }),
			session({ startedAt: '2026-11-16T08:00:00', elapsedMs: 25 * 60_000, status: 'skipped' })
		];
		const stats = computeDashboardStats(sessions, NOW, 7);
		expect(stats.peakHour).toBe(8);
		expect(stats.completionRate).toBeCloseTo(2 / 3);
		expect(stats.modeBreakdown[0].mode).toBe('pomodoro');
		expect(stats.longestSessionMs).toBe(30 * 60_000);
	});

	it('focus score: perfect week scores 100', () => {
		const sessions: FocusSession[] = [];
		for (let i = 6; i >= 0; i -= 1) {
			const d = new Date(2026, 10, 16 - i, 9, 0, 0);
			sessions.push(session({ startedAt: d.toISOString(), elapsedMs: 45 * 60_000 }));
		}
		const stats = computeDashboardStats(sessions, NOW, 7);
		expect(stats.focusScore).toBe(100);
		expect(stats.focusScoreQualifier).toBe('exceptional');
	});

	it('focus score: empty week rests', () => {
		const stats = computeDashboardStats([], NOW, 7);
		expect(stats.focusScore).toBe(0);
		expect(stats.focusScoreQualifier).toBe('rest');
	});

	it('streak reflects consecutive days', () => {
		const sessions: FocusSession[] = [];
		for (const day of [14, 15, 16]) {
			sessions.push(session({ startedAt: `2026-11-${String(day).padStart(2, '0')}T09:00:00` }));
		}
		expect(computeDashboardStats(sessions, NOW, 7).streak).toBe(3);
	});
});

describe('evaluateAchievements', () => {
	it('first focus unlocks with one session; others show progress', () => {
		const list = evaluateAchievements([session({})], NOW);
		expect(list.find((a) => a.id === 'firstFocus')?.unlocked).toBe(true);
		expect(list.find((a) => a.id === 'centuryClub')?.progress).toBeCloseTo(0.01);
	});

	it('pomodoro master counts pomodoro sessions only', () => {
		const sessions = [
			session({ mode: 'pomodoro' }),
			session({ mode: 'stopwatch' }),
			session({ mode: 'pomodoro' })
		];
		const pm = evaluateAchievements(sessions, NOW).find((a) => a.id === 'pomodoroMaster')!;
		expect(pm.progress).toBeCloseTo(2 / 100);
	});

	it('deep diver requires 45-minute sessions; early bird counts morning starts', () => {
		const sessions = [
			session({ startedAt: '2026-11-16T07:30:00', elapsedMs: 50 * 60_000 }),
			session({ startedAt: '2026-11-15T07:45:00', elapsedMs: 20 * 60_000 }),
			session({ startedAt: '2026-11-14T12:00:00', elapsedMs: 46 * 60_000 })
		];
		const list = evaluateAchievements(sessions, NOW);
		expect(list.find((a) => a.id === 'deepDiver')!.progress).toBeCloseTo(2 / 10);
		expect(list.find((a) => a.id === 'earlyBird')!.progress).toBeCloseTo(2 / 10);
	});

	it('week warrior tracks the streak', () => {
		const sessions: FocusSession[] = [];
		for (let day = 10; day <= 16; day += 1) {
			sessions.push(session({ startedAt: `2026-11-${String(day).padStart(2, '0')}T09:00:00` }));
		}
		expect(evaluateAchievements(sessions, NOW).find((a) => a.id === 'weekWarrior')!.unlocked).toBe(true);
	});
});

describe('buildPeriodReview', () => {
	const task = (id: string, title: string): Task => ({
		id,
		title,
		status: 'active',
		priority: 'none',
		energy: 'shallow',
		estimatedPomodoros: 1,
		list: 'today',
		order: 0,
		createdAt: '2026-11-01T09:00:00',
		updatedAt: '2026-11-01T09:00:00'
	});

	it('compares against the previous period with trend', () => {
		const sessions = [
			session({ startedAt: '2026-11-16T09:00:00', elapsedMs: 40 * 60_000, taskId: 't1' }),
			session({ startedAt: '2026-11-09T09:00:00', elapsedMs: 20 * 60_000 })
		];
		const review = buildPeriodReview(sessions, [task('t1', 'Docs')], NOW, 7);
		expect(review.focusSeconds).toBe(40 * 60);
		expect(review.previousFocusSeconds).toBe(20 * 60);
		expect(review.trend).toBe('up');
		expect(review.trendPct).toBeCloseTo(1);
		expect(review.topTasks[0]?.title).toBe('Docs');
		expect(review.dominantMode).toBe('pomodoro');
	});

	it('flat trend when both periods are equal; down when shrinking', () => {
		const equal = [
			session({ startedAt: '2026-11-16T09:00:00', elapsedMs: 20 * 60_000 }),
			session({ startedAt: '2026-11-09T09:00:00', elapsedMs: 20 * 60_000 })
		];
		expect(buildPeriodReview(equal, [], NOW, 7).trend).toBe('flat');

		const shrinking = [
			session({ startedAt: '2026-11-16T09:00:00', elapsedMs: 10 * 60_000 }),
			session({ startedAt: '2026-11-09T09:00:00', elapsedMs: 30 * 60_000 })
		];
		const down = buildPeriodReview(shrinking, [], NOW, 7);
		expect(down.trend).toBe('down');
		expect(down.trendPct).toBeCloseTo(2 / 3);
	});
});
