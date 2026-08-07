/**
 * Pure Last-Writer-Wins merge helpers for applying a server snapshot onto the
 * local store. All functions are deterministic and side-effect-free so they
 * can be unit-tested without IndexedDB or a DOM.
 *
 * Identity keys:
 *  - Task:      `id` (== backend `syncId`, a client-generated UUID)
 *  - Session:   `id` (== backend session UUID)
 *
 * Conflict rule: for a shared key, the record with the greater `updatedAt`
 * (ISO-8601 lexical compare) wins. Ties favor the remote (server is authority).
 */
import type { FocusSession, Preferences, Task } from '$lib/domain/entities/types';

/** Lexical max of two ISO timestamps; empty/missing sorts first. */
function latest(a: string | null | undefined, b: string | null | undefined): string {
	const av = a ?? '';
	const bv = b ?? '';
	return av >= bv ? av : bv;
}

/**
 * Merge two task lists by `id`, keeping the newest version of each task.
 * Tasks present in only one side are preserved (no deletions for MVP).
 */
export function mergeTasks(local: Task[], remote: Task[]): Task[] {
	const byId = new Map<string, Task>();
	for (const t of local) byId.set(t.id, t);
	for (const t of remote) {
		const existing = byId.get(t.id);
		if (!existing) {
			byId.set(t.id, t);
		} else if (latest(existing.updatedAt, t.updatedAt) === t.updatedAt) {
			byId.set(t.id, t);
		}
	}
	// Stable-ish ordering: active first by order, then by updatedAt desc.
	return Array.from(byId.values()).sort(
		(a, b) => a.order - b.order || b.updatedAt.localeCompare(a.updatedAt)
	);
}

/**
 * Merge two session lists by `id`, keeping the newest version of each session.
 */
export function mergeSessions(local: FocusSession[], remote: FocusSession[]): FocusSession[] {
	const byId = new Map<string, FocusSession>();
	for (const s of local) byId.set(s.id, s);
	for (const s of remote) {
		const existing = byId.get(s.id);
		if (!existing) {
			byId.set(s.id, s);
		} else if (latest(existing.updatedAt, s.updatedAt) === s.updatedAt) {
			byId.set(s.id, s);
		}
	}
	// Newest first (matches listSessions ordering).
	return Array.from(byId.values()).sort((a, b) => {
		const ak = a.startedAt ?? a.createdAt;
		const bk = b.startedAt ?? b.createdAt;
		return bk.localeCompare(ak);
	});
}

/**
 * Overlay remote prefs onto local. Device-local keys (`onboardingCompleted`)
 * are preserved from local. Remote wins per-key (server is authority for the
 * synced subset).
 */
export function mergePrefs(local: Preferences, remote: Partial<Preferences>): Preferences {
	return {
		...local,
		...remote,
		onboardingCompleted: local.onboardingCompleted
	};
}
