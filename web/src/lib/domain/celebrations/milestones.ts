/**
 * Milestone celebrations — pure mirror of android
 * domain/celebration/MilestoneCelebration.kt (#807) and the iOS
 * StreakRecordCelebration: priority FirstSession > StreakDay (7/14/30) >
 * SessionCount (10/50/100, latched) > PersonalBest (floor 30 min).
 * One milestone per completed work session; latches persist.
 */

export const STREAK_THRESHOLDS = [7, 14, 30] as const;
export const SESSION_COUNT_THRESHOLDS = [10, 50, 100] as const;
export const PERSONAL_BEST_FLOOR_MS = 30 * 60_000;

export interface MilestoneLatches {
	firstSessionCelebrated: boolean;
	celebratedStreakDays: number[];
	celebratedSessionCounts: number[];
	bestSessionMs: number;
}

export const FRESH_LATCHES: MilestoneLatches = {
	firstSessionCelebrated: false,
	celebratedStreakDays: [],
	celebratedSessionCounts: [],
	bestSessionMs: 0
};

export type Milestone =
	| { kind: 'firstSession' }
	| { kind: 'streak'; days: number }
	| { kind: 'sessionCount'; count: number }
	| { kind: 'personalBest'; minutes: number };

export interface MilestoneInput {
	/** Work sessions completed all-time, INCLUDING the one just finished. */
	totalCompletedSessions: number;
	/** Current streak days including today. */
	currentStreakDays: number;
	/** Duration of the just-completed work session (ms). */
	latestSessionMs: number;
}

/**
 * Evaluate the next milestone to celebrate. Pure: returns the updated latches
 * that the caller must persist (even when no milestone fires, the best may
 * advance).
 */
export function evaluateMilestone(
	input: MilestoneInput,
	latches: MilestoneLatches
): { milestone: Milestone | null; latches: MilestoneLatches } {
	let next: MilestoneLatches = { ...latches };

	// Personal best advances regardless of celebration priority.
	const beatsBest =
		input.latestSessionMs > next.bestSessionMs && input.latestSessionMs >= PERSONAL_BEST_FLOOR_MS;

	// 1. First session ever.
	if (!next.firstSessionCelebrated && input.totalCompletedSessions >= 1) {
		next = { ...next, firstSessionCelebrated: true };
		return { milestone: { kind: 'firstSession' }, latches: next };
	}

	// 2. Streak days (highest uncelebrated threshold reached). Latch every
	//    threshold at or below the fired one so overdue users never get
	//    spammed by lower thresholds on later sessions.
	const streakDays = STREAK_THRESHOLDS.filter(
		(d) => input.currentStreakDays >= d && !next.celebratedStreakDays.includes(d)
	);
	if (streakDays.length > 0) {
		const days = Math.max(...streakDays);
		next = {
			...next,
			celebratedStreakDays: [
				...new Set([...next.celebratedStreakDays, ...STREAK_THRESHOLDS.filter((d) => d <= days)])
			]
		};
		return { milestone: { kind: 'streak', days }, latches: next };
	}

	// 3. Session count (highest uncelebrated threshold reached; latches cover
	//    overdue users who already exceed the thresholds).
	const counts = SESSION_COUNT_THRESHOLDS.filter(
		(c) => input.totalCompletedSessions >= c && !next.celebratedSessionCounts.includes(c)
	);
	if (counts.length > 0) {
		const count = Math.max(...counts);
		next = {
			...next,
			celebratedSessionCounts: [
				...new Set([
					...next.celebratedSessionCounts,
					...SESSION_COUNT_THRESHOLDS.filter((c) => c <= count)
				])
			]
		};
		return { milestone: { kind: 'sessionCount', count }, latches: next };
	}

	// 4. Personal best (only when the just-finished session sets a new one).
	if (beatsBest) {
		next = { ...next, bestSessionMs: input.latestSessionMs };
		return {
			milestone: { kind: 'personalBest', minutes: Math.round(input.latestSessionMs / 60_000) },
			latches: next
		};
	}

	return { milestone: null, latches: next };
}

/** Streak record: strictly greater than the previous best streak. */
export function isStreakRecord(currentStreakDays: number, bestStreakDays: number): boolean {
	return currentStreakDays > bestStreakDays && currentStreakDays > 0;
}
