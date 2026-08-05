import 'fake-indexeddb/auto';
import { beforeEach, describe, expect, it } from 'vitest';
import {
	closeDb,
	getDeviceId,
	getPreferences,
	listActiveTasks,
	listSessions,
	openDb,
	resetDbForTests,
	savePreferences,
	saveSession,
	upsertTask,
	removeTask
} from '$lib/data/local/idb';
import type { FocusSession, Task } from '$lib/domain/entities/types';

describe('IndexedDB repositories', () => {
	beforeEach(async () => {
		await resetDbForTests();
		await openDb();
	});

	it('persists device id stably across open cycles', async () => {
		const first = await getDeviceId();
		expect(first).toMatch(
			/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
		);
		await closeDb();
		await openDb();
		const second = await getDeviceId();
		expect(second).toBe(first);
	});

	it('upserts and lists active tasks; survives reopen', async () => {
		const task = makeTask('t1', 'Write gates');
		await upsertTask(task);
		await upsertTask(makeTask('t2', 'Ship W1', 'completed'));

		let active = await listActiveTasks();
		expect(active).toHaveLength(1);
		expect(active[0].title).toBe('Write gates');

		await closeDb();
		await openDb();
		active = await listActiveTasks();
		expect(active).toHaveLength(1);
		expect(active[0].id).toBe('t1');
	});

	it('removes a task by id', async () => {
		await upsertTask(makeTask('t1', 'A'));
		await removeTask('t1');
		expect(await listActiveTasks()).toEqual([]);
	});

	it('saves sessions and lists them newest-first', async () => {
		await saveSession(makeSession('s1', '2026-08-05T09:00:00.000Z'));
		await saveSession(makeSession('s2', '2026-08-05T11:00:00.000Z'));
		const list = await listSessions();
		expect(list.map((s) => s.id)).toEqual(['s2', 's1']);
	});

	it('loads default preferences and persists updates', async () => {
		const defaults = await getPreferences();
		expect(defaults.onboardingCompleted).toBe(false);
		expect(defaults.locale).toBe('en');

		await savePreferences({ ...defaults, locale: 'es', onboardingCompleted: true });
		const saved = await getPreferences();
		expect(saved.locale).toBe('es');
		expect(saved.onboardingCompleted).toBe(true);
	});
});

function makeTask(id: string, title: string, status: Task['status'] = 'active'): Task {
	const now = '2026-08-05T10:00:00.000Z';
	return {
		id,
		title,
		status,
		priority: 'medium',
		energy: 'medium',
		estimatedPomodoros: 1,
		list: 'inbox',
		order: 0,
		createdAt: now,
		updatedAt: now
	};
}

function makeSession(id: string, startedAt: string): FocusSession {
	return {
		id,
		mode: 'pomodoro',
		status: 'completed',
		startedAt,
		elapsedMs: 1000,
		segmentStartedAt: null,
		targetMs: 25 * 60 * 1000,
		taskId: null,
		journal: '',
		completedAt: startedAt,
		createdAt: startedAt,
		updatedAt: startedAt
	};
}
