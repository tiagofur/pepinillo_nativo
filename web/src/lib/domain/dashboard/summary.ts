import type { FocusSession } from '$lib/domain/entities/types';
import { filterSessionsForFreeAnalytics } from '$lib/domain/gates/freeLimits';

export interface PeriodSummary {
	sessionCount: number;
	focusMinutes: number;
}

export interface DashboardSummary {
	today: PeriodSummary;
	last7Days: PeriodSummary;
}

const COUNTABLE: ReadonlySet<FocusSession['status']> = new Set(['completed', 'skipped']);

export function summarizeSessions(
	sessions: FocusSession[],
	now: Date = new Date()
): DashboardSummary {
	const inWindow = filterSessionsForFreeAnalytics(sessions, now);
	const todayStart = startOfUtcDay(now);

	const todaySessions = inWindow.filter((s) => {
		if (!s.startedAt || !COUNTABLE.has(s.status)) return false;
		return new Date(s.startedAt) >= todayStart;
	});

	const weekSessions = inWindow.filter((s) => COUNTABLE.has(s.status));

	return {
		today: reducePeriod(todaySessions),
		last7Days: reducePeriod(weekSessions)
	};
}

function reducePeriod(sessions: FocusSession[]): PeriodSummary {
	const focusMs = sessions.reduce((sum, s) => sum + s.elapsedMs, 0);
	return {
		sessionCount: sessions.length,
		focusMinutes: Math.round(focusMs / 60_000)
	};
}

function startOfUtcDay(date: Date): Date {
	return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
