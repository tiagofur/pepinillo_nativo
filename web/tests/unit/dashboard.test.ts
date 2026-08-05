import { describe, expect, it } from 'vitest';
import { summarizeSessions } from '$lib/domain/dashboard/summary';
import type { FocusSession } from '$lib/domain/entities/types';

describe('Dashboard free summary', () => {
	it('sums today focus minutes and session count', () => {
		const now = new Date('2026-08-05T18:00:00.000Z');
		const sessions: FocusSession[] = [
			session('s1', 'pomodoro', '2026-08-05T10:00:00.000Z', 25 * 60 * 1000),
			session('s2', 'stopwatch', '2026-08-05T14:00:00.000Z', 10 * 60 * 1000),
			session('s3', 'pomodoro', '2026-08-04T10:00:00.000Z', 25 * 60 * 1000)
		];
		const summary = summarizeSessions(sessions, now);
		expect(summary.today.sessionCount).toBe(2);
		expect(summary.today.focusMinutes).toBe(35);
		expect(summary.last7Days.sessionCount).toBe(3);
		expect(summary.last7Days.focusMinutes).toBe(60);
	});

	it('excludes sessions outside free 7-day window from last7Days', () => {
		const now = new Date('2026-08-05T12:00:00.000Z');
		const sessions = [
			session('old', 'pomodoro', '2026-07-20T10:00:00.000Z', 50 * 60 * 1000),
			session('recent', 'stopwatch', '2026-08-03T10:00:00.000Z', 15 * 60 * 1000)
		];
		const summary = summarizeSessions(sessions, now);
		expect(summary.last7Days.sessionCount).toBe(1);
		expect(summary.last7Days.focusMinutes).toBe(15);
		expect(summary.today.sessionCount).toBe(0);
	});

	it('counts completed and skipped, ignores idle/running for summary totals', () => {
		const now = new Date('2026-08-05T12:00:00.000Z');
		const sessions: FocusSession[] = [
			{ ...session('done', 'pomodoro', '2026-08-05T09:00:00.000Z', 20 * 60 * 1000), status: 'completed' },
			{ ...session('skip', 'stopwatch', '2026-08-05T10:00:00.000Z', 5 * 60 * 1000), status: 'skipped' },
			{ ...session('run', 'pomodoro', '2026-08-05T11:00:00.000Z', 1 * 60 * 1000), status: 'running' }
		];
		const summary = summarizeSessions(sessions, now);
		expect(summary.today.sessionCount).toBe(2);
		expect(summary.today.focusMinutes).toBe(25);
	});
});

function session(
	id: string,
	mode: FocusSession['mode'],
	startedAt: string,
	elapsedMs: number
): FocusSession {
	return {
		id,
		mode,
		status: 'completed',
		startedAt,
		elapsedMs,
		segmentStartedAt: null,
		targetMs: mode === 'pomodoro' ? 25 * 60 * 1000 : null,
		taskId: null,
		journal: '',
		completedAt: startedAt,
		createdAt: startedAt,
		updatedAt: startedAt
	};
}
