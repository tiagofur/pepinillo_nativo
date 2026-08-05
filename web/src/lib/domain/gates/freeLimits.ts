import type { FocusMode, FocusSession } from '$lib/domain/entities/types';
import {
	FREE_ANALYTICS_DAYS,
	FREE_MAX_ACTIVE_TASKS,
	FREE_MODES
} from '$lib/domain/entities/types';

export type EntitlementTier = 'free' | 'everywhere';

export const FREE_LIMITS = {
	maxActiveTasks: FREE_MAX_ACTIVE_TASKS,
	analyticsDays: FREE_ANALYTICS_DAYS,
	modes: FREE_MODES
} as const;

export function canUseMode(mode: FocusMode, tier: EntitlementTier): boolean {
	if (tier === 'everywhere') return true;
	return (FREE_MODES as readonly FocusMode[]).includes(mode);
}

export function maxActiveTasks(tier: EntitlementTier): number {
	return tier === 'everywhere' ? Infinity : FREE_MAX_ACTIVE_TASKS;
}

export function canCreateActiveTask(currentActiveCount: number, tier: EntitlementTier): boolean {
	return currentActiveCount < maxActiveTasks(tier);
}

export function canUseSubtasks(tier: EntitlementTier): boolean {
	return tier === 'everywhere';
}

export function canUseRecurrence(tier: EntitlementTier): boolean {
	return tier === 'everywhere';
}

export function canExport(tier: EntitlementTier): boolean {
	return tier === 'everywhere';
}

export function canUseSync(tier: EntitlementTier): boolean {
	return tier === 'everywhere';
}

export function canUsePremiumTheme(tier: EntitlementTier): boolean {
	return tier === 'everywhere';
}

/**
 * Free analytics: today + last N calendar days inclusive from `now`.
 * A session is kept if its startedAt date is on or after (today - FREE_ANALYTICS_DAYS).
 */
export function filterSessionsForFreeAnalytics(
	sessions: FocusSession[],
	now: Date = new Date()
): FocusSession[] {
	const cutoff = startOfUtcDay(now);
	cutoff.setUTCDate(cutoff.getUTCDate() - FREE_ANALYTICS_DAYS);

	return sessions.filter((session) => {
		if (!session.startedAt) return false;
		const started = new Date(session.startedAt);
		return started >= cutoff;
	});
}

function startOfUtcDay(date: Date): Date {
	return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
