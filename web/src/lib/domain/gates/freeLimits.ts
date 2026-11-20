import type { FocusMode, FocusSession } from '$lib/domain/entities/types';
import {
	FREE_ANALYTICS_DAYS,
	FREE_MAX_ACTIVE_TASKS,
	FREE_MODES
} from '$lib/domain/entities/types';

/**
 * Local gate tiers (#952). `pepinillo_plus` unlocks every LOCAL premium
 * surface (modes, tasks, structure, themes, analytics) but NOT multi-device
 * sync — that stays Everywhere-only (#942: Plus gets a single-device backup
 * lane on the backend). AI cards follow the same Everywhere-only rule (the
 * backend denies ai_insights for pepinillo_plus).
 */
export type EntitlementTier = 'free' | 'pepinillo_plus' | 'everywhere';

export const FREE_LIMITS = {
	maxActiveTasks: FREE_MAX_ACTIVE_TASKS,
	analyticsDays: FREE_ANALYTICS_DAYS,
	modes: FREE_MODES
} as const;

/** Local premium = any paid tier; sync and cloud AI remain Everywhere-only. */
export function hasLocalPremium(tier: EntitlementTier): boolean {
	return tier !== 'free';
}

export function canUseMode(mode: FocusMode, tier: EntitlementTier): boolean {
	if (hasLocalPremium(tier)) return true;
	return (FREE_MODES as readonly FocusMode[]).includes(mode);
}

export function maxActiveTasks(tier: EntitlementTier): number {
	return hasLocalPremium(tier) ? Infinity : FREE_MAX_ACTIVE_TASKS;
}

export function canCreateActiveTask(currentActiveCount: number, tier: EntitlementTier): boolean {
	return currentActiveCount < maxActiveTasks(tier);
}

export function canUseSubtasks(tier: EntitlementTier): boolean {
	return hasLocalPremium(tier);
}

export function canUseRecurrence(tier: EntitlementTier): boolean {
	return hasLocalPremium(tier);
}

export function canExport(tier: EntitlementTier): boolean {
	return hasLocalPremium(tier);
}

export function canUseSync(tier: EntitlementTier): boolean {
	return tier === 'everywhere';
}

/** Free analytics cover today + last 7 days; longer periods are premium. */
export function canUseAnalyticsPeriod(days: 7 | 30 | 365, tier: EntitlementTier): boolean {
	if (tier !== 'free') return true;
	return days <= FREE_ANALYTICS_DAYS;
}

export function canUsePremiumTheme(tier: EntitlementTier): boolean {
	return hasLocalPremium(tier);
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
