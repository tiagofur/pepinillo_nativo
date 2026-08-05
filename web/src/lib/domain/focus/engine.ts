import type { FocusMode, FocusSession } from '$lib/domain/entities/types';

export interface PomodoroOptions {
	workMinutes?: number;
}

let sessionSeq = 0;

function nextId(): string {
	sessionSeq += 1;
	return `session-${sessionSeq}-${Math.random().toString(36).slice(2, 9)}`;
}

function nowIso(now: string | Date): string {
	return typeof now === 'string' ? now : now.toISOString();
}

function msBetween(fromIso: string, toIso: string): number {
	return Math.max(0, new Date(toIso).getTime() - new Date(fromIso).getTime());
}

export function createIdleSession(
	mode: FocusMode,
	options: PomodoroOptions = {}
): FocusSession {
	const workMinutes = options.workMinutes ?? 25;
	const targetMs = mode === 'pomodoro' ? workMinutes * 60 * 1000 : null;
	const stamp = new Date(0).toISOString();

	return {
		id: nextId(),
		mode,
		status: 'idle',
		startedAt: null,
		elapsedMs: 0,
		segmentStartedAt: null,
		targetMs,
		taskId: null,
		journal: '',
		completedAt: null,
		createdAt: stamp,
		updatedAt: stamp
	};
}

export function startSession(session: FocusSession, now: string | Date): FocusSession {
	if (session.status !== 'idle') {
		return session;
	}

	const t = nowIso(now);
	return {
		...session,
		status: 'running',
		startedAt: t,
		segmentStartedAt: t,
		elapsedMs: 0,
		completedAt: null,
		updatedAt: t
	};
}

/**
 * Commit live segment into elapsedMs and clear segmentStartedAt.
 */
function commitLive(session: FocusSession, now: string): FocusSession {
	if (session.status !== 'running' || !session.segmentStartedAt) {
		return session;
	}
	const elapsedMs = session.elapsedMs + msBetween(session.segmentStartedAt, now);
	return {
		...session,
		elapsedMs,
		segmentStartedAt: null,
		updatedAt: now
	};
}

export function pauseSession(session: FocusSession, now: string | Date): FocusSession {
	if (session.status !== 'running') {
		return session;
	}
	const t = nowIso(now);
	const committed = commitLive(session, t);
	return {
		...committed,
		status: 'paused',
		segmentStartedAt: null,
		updatedAt: t
	};
}

export function resumeSession(session: FocusSession, now: string | Date): FocusSession {
	if (session.status !== 'paused') {
		return session;
	}
	const t = nowIso(now);
	return {
		...session,
		status: 'running',
		segmentStartedAt: t,
		updatedAt: t
	};
}

/**
 * Wall-clock tick: recompute display elapsed from committed + live segment.
 * Folds segment into elapsed and restarts segment at `now` so successive ticks
 * do not double-count.
 */
export function tickSession(session: FocusSession, now: string | Date): FocusSession {
	if (session.status !== 'running' || !session.segmentStartedAt) {
		return session;
	}

	const t = nowIso(now);
	const elapsedMs = session.elapsedMs + msBetween(session.segmentStartedAt, t);

	if (session.targetMs != null && elapsedMs >= session.targetMs) {
		return {
			...session,
			status: 'completed',
			elapsedMs: session.targetMs,
			segmentStartedAt: null,
			completedAt: t,
			updatedAt: t
		};
	}

	return {
		...session,
		elapsedMs,
		segmentStartedAt: t,
		updatedAt: t
	};
}

/**
 * Recompute elapsed when tab becomes visible again.
 * Uses wall-clock from segment start; does not claim OS background reliability.
 */
export function recomputeOnVisible(session: FocusSession, now: string | Date): FocusSession {
	return tickSession(session, now);
}

export function skipSession(session: FocusSession, now: string | Date): FocusSession {
	if (session.status !== 'running' && session.status !== 'paused') {
		return session;
	}
	const t = nowIso(now);
	const committed =
		session.status === 'running' ? commitLive(session, t) : { ...session, updatedAt: t };
	return {
		...committed,
		status: 'skipped',
		segmentStartedAt: null,
		completedAt: t,
		updatedAt: t
	};
}

export function completeSession(session: FocusSession, now: string | Date): FocusSession {
	if (session.status !== 'running' && session.status !== 'paused') {
		return session;
	}
	const t = nowIso(now);
	const committed =
		session.status === 'running' ? commitLive(session, t) : { ...session, updatedAt: t };
	return {
		...committed,
		status: 'completed',
		segmentStartedAt: null,
		completedAt: t,
		updatedAt: t
	};
}

export function setJournal(session: FocusSession, journal: string): FocusSession {
	return { ...session, journal };
}

export function linkTask(session: FocusSession, taskId: string | null): FocusSession {
	return { ...session, taskId };
}

/** Display remaining ms for countdown modes; null for stopwatch. */
export function remainingMs(session: FocusSession, now: string | Date): number | null {
	if (session.targetMs == null) return null;
	return Math.max(0, session.targetMs - liveElapsedMs(session, now));
}

export function liveElapsedMs(session: FocusSession, now: string | Date): number {
	if (session.status === 'running' && session.segmentStartedAt) {
		return session.elapsedMs + msBetween(session.segmentStartedAt, nowIso(now));
	}
	return session.elapsedMs;
}
