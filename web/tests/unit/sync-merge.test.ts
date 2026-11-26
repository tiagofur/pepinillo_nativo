import { describe, expect, it } from 'vitest';
import { mergePrefs, mergeSessions, mergeTasks } from '$lib/data/sync/merge';
import { DEFAULT_PREFERENCES, type FocusSession, type Preferences, type Task } from '$lib/domain/entities/types';

function makeTask(overrides: Partial<Task>): Task {
	return {
		id: 't1',
		title: 'task',
		status: 'active',
		priority: 'medium',
		energy: 'shallow',
		estimatedPomodoros: 1,
		list: 'today',
		order: 0,
		createdAt: '2026-08-01T00:00:00.000Z',
		updatedAt: '2026-08-01T00:00:00.000Z',
		...overrides
	};
}

function makeSession(overrides: Partial<FocusSession>): FocusSession {
	return {
		id: 's1',
		mode: 'pomodoro',
		status: 'completed',
		startedAt: '2026-08-01T10:00:00.000Z',
		elapsedMs: 60000,
		segmentStartedAt: null,
		targetMs: 1500000,
		taskId: null,
		journal: '',
		completedAt: '2026-08-01T10:01:00.000Z',
		createdAt: '2026-08-01T10:00:00.000Z',
		updatedAt: '2026-08-01T10:01:00.000Z',
		...overrides
	};
}

describe('mergeTasks (LWW)', () => {
	it('keeps the local version when it is newer', () => {
		const local = [makeTask({ id: 'a', updatedAt: '2026-08-05T12:00:00.000Z' })];
		const remote = [makeTask({ id: 'a', updatedAt: '2026-08-05T10:00:00.000Z' })];
		const merged = mergeTasks(local, remote);
		expect(merged).toHaveLength(1);
		expect(merged[0].updatedAt).toBe('2026-08-05T12:00:00.000Z');
	});

	it('takes the remote version when it is newer', () => {
		const local = [makeTask({ id: 'a', updatedAt: '2026-08-05T10:00:00.000Z' })];
		const remote = [makeTask({ id: 'a', updatedAt: '2026-08-05T12:00:00.000Z' })];
		const merged = mergeTasks(local, remote);
		expect(merged).toHaveLength(1);
		expect(merged[0].updatedAt).toBe('2026-08-05T12:00:00.000Z');
	});

	it('unions disjoint ids', () => {
		const local = [makeTask({ id: 'a' })];
		const remote = [makeTask({ id: 'b' })];
		const merged = mergeTasks(local, remote);
		expect(merged.map((t) => t.id).sort()).toEqual(['a', 'b']);
	});

	it('favors remote on tie (server is authority)', () => {
		const ts = '2026-08-05T10:00:00.000Z';
		const local = [makeTask({ id: 'a', title: 'local', updatedAt: ts })];
		const remote = [makeTask({ id: 'a', title: 'remote', updatedAt: ts })];
		const merged = mergeTasks(local, remote);
		expect(merged[0].title).toBe('remote');
	});
});

describe('mergeSessions (LWW)', () => {
	it('keeps newest session by id', () => {
		const local = [makeSession({ id: 'x', updatedAt: '2026-08-05T10:00:00.000Z' })];
		const remote = [makeSession({ id: 'x', updatedAt: '2026-08-05T12:00:00.000Z', journal: 'from phone' })];
		const merged = mergeSessions(local, remote);
		expect(merged).toHaveLength(1);
		expect(merged[0].journal).toBe('from phone');
	});

	it('sorts newest first', () => {
		const local = [makeSession({ id: 'old', startedAt: '2026-08-01T10:00:00.000Z' })];
		const remote = [makeSession({ id: 'new', startedAt: '2026-08-06T10:00:00.000Z' })];
		const merged = mergeSessions(local, remote);
		expect(merged[0].id).toBe('new');
	});
});

describe('mergePrefs', () => {
	it('overlays remote keys onto local', () => {
		const local: Preferences = { ...DEFAULT_PREFERENCES, theme: 'light', pomodoroWorkMinutes: 25 };
		const merged = mergePrefs(local, { theme: 'dark' });
		expect(merged.theme).toBe('dark');
		expect(merged.pomodoroWorkMinutes).toBe(25);
	});

	it('preserves local onboardingCompleted', () => {
		const local: Preferences = { ...DEFAULT_PREFERENCES, onboardingCompleted: true };
		const merged = mergePrefs(local, { onboardingCompleted: false });
		expect(merged.onboardingCompleted).toBe(true);
	});
});

describe('mergeTasks with canonical payloads (#989 PR-C, S6)', () => {
	it('a tie no longer loses fields because the remote copy is full-fidelity', () => {
		const stamp = '2026-11-25T10:00:00.000Z';
		const local = {
			id: 't1',
			title: 'Same',
			status: 'active' as const,
			priority: 'none' as const,
			energy: 'shallow' as const,
			estimatedPomodoros: 1,
			list: 'inbox' as const,
			order: 3,
			createdAt: stamp,
			updatedAt: stamp,
			dueDate: '2026-11-26',
			scheduledForToday: true,
			notes: 'kept',
			completedPomodoros: 7,
			subtasks: [{ id: 's1', title: 'sub', isCompleted: false, sortOrder: 0, createdAt: stamp }]
		};
		// Server echo of the same task (same updatedAt stamp, full payload).
		const remote = {
			...local,
			completedPomodoros: 7,
			focusedSeconds: 5400,
			trackingMode: 'pomodoro'
		};
		const merged = mergeTasks([local], [remote]);
		const winner = merged.find((t) => t.id === 't1')!;
		expect(winner.dueDate).toBe('2026-11-26');
		expect(winner.scheduledForToday).toBe(true);
		expect(winner.notes).toBe('kept');
		expect(winner.subtasks).toHaveLength(1);
		expect(winner.completedPomodoros).toBe(7);
		expect(winner.focusedSeconds).toBe(5400);
	});
});
