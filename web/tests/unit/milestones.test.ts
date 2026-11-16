import { describe, expect, it } from 'vitest';
import {
	evaluateMilestone,
	FRESH_LATCHES,
	isStreakRecord,
	PERSONAL_BEST_FLOOR_MS
} from '$lib/domain/celebrations/milestones';

describe('evaluateMilestone priority', () => {
	it('celebrates the first session once', () => {
		const r = evaluateMilestone(
			{ totalCompletedSessions: 1, currentStreakDays: 1, latestSessionMs: 25 * 60_000 },
			FRESH_LATCHES
		);
		expect(r.milestone).toEqual({ kind: 'firstSession' });
		expect(r.latches.firstSessionCelebrated).toBe(true);
		// second session: no repeat
		const r2 = evaluateMilestone(
			{ totalCompletedSessions: 2, currentStreakDays: 2, latestSessionMs: 25 * 60_000 },
			r.latches
		);
		expect(r2.milestone).toBeNull();
	});

	it('streak outranks session count', () => {
		const latches = { ...FRESH_LATCHES, firstSessionCelebrated: true };
		const r = evaluateMilestone(
			{ totalCompletedSessions: 12, currentStreakDays: 7, latestSessionMs: 25 * 60_000 },
			latches
		);
		expect(r.milestone).toEqual({ kind: 'streak', days: 7 });
	});

	it('celebrates each streak threshold once', () => {
		const latches = { ...FRESH_LATCHES, firstSessionCelebrated: true, celebratedStreakDays: [7] };
		const r = evaluateMilestone(
			{ totalCompletedSessions: 20, currentStreakDays: 14, latestSessionMs: 25 * 60_000 },
			latches
		);
		expect(r.milestone).toEqual({ kind: 'streak', days: 14 });
	});

	it('session count latches cover overdue users without spam', () => {
		const latches = {
			...FRESH_LATCHES,
			firstSessionCelebrated: true,
			celebratedStreakDays: [7, 14, 30]
		};
		const r = evaluateMilestone(
			{ totalCompletedSessions: 128, currentStreakDays: 3, latestSessionMs: 20 * 60_000 },
			latches
		);
		expect(r.milestone).toEqual({ kind: 'sessionCount', count: 100 });
		const r2 = evaluateMilestone(
			{ totalCompletedSessions: 129, currentStreakDays: 3, latestSessionMs: 20 * 60_000 },
			r.latches
		);
		expect(r2.milestone).toBeNull();
	});

	it('personal best requires the 30-minute floor and beats only', () => {
		const latches = {
			...FRESH_LATCHES,
			firstSessionCelebrated: true,
			celebratedStreakDays: [7, 14, 30],
			celebratedSessionCounts: [10, 50, 100]
		};
		const below = evaluateMilestone(
			{ totalCompletedSessions: 150, currentStreakDays: 1, latestSessionMs: 29 * 60_000 },
			latches
		);
		expect(below.milestone).toBeNull();

		const record = evaluateMilestone(
			{ totalCompletedSessions: 151, currentStreakDays: 1, latestSessionMs: 47 * 60_000 },
			below.latches
		);
		expect(record.milestone).toEqual({ kind: 'personalBest', minutes: 47 });
		expect(record.latches.bestSessionMs).toBe(47 * 60_000);

		const again = evaluateMilestone(
			{ totalCompletedSessions: 152, currentStreakDays: 1, latestSessionMs: 45 * 60_000 },
			record.latches
		);
		expect(again.milestone).toBeNull();
	});

	it('does not celebrate a best below the floor even when it advances the max', () => {
		const latches = { ...FRESH_LATCHES, firstSessionCelebrated: true, bestSessionMs: 0 };
		const r = evaluateMilestone(
			{ totalCompletedSessions: 5, currentStreakDays: 1, latestSessionMs: PERSONAL_BEST_FLOOR_MS - 1 },
			latches
		);
		expect(r.milestone).toBeNull();
		expect(r.latches.bestSessionMs).toBe(0);
	});
});

describe('isStreakRecord', () => {
	it('fires only above a positive previous best', () => {
		expect(isStreakRecord(3, 0)).toBe(true);
		expect(isStreakRecord(7, 5)).toBe(true);
		expect(isStreakRecord(5, 5)).toBe(false);
		expect(isStreakRecord(0, 0)).toBe(false);
	});
});
