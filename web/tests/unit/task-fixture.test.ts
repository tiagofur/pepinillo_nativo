import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { remoteToTask, taskToRemote } from '$lib/data/sync/mappers';
import { localDateKey } from '$lib/domain/tasks/recurrence';
import type { RemoteTask } from '$lib/data/remote/types';

/**
 * Issue #989 (S7): every platform decodes the same canonical wire fixture
 * versioned in the repo (contracts/fixtures/task-canonical-989.json) and
 * asserts the task-model fields survive its mapper — this is the web leg.
 */
describe('canonical wire fixture (S7)', () => {
	const fixturePath = resolve(fileURLToPath(import.meta.url), '../../../../contracts/fixtures/task-canonical-989.json');
	const fixture = JSON.parse(readFileSync(fixturePath, 'utf8')) as RemoteTask;

	it('decodes and round-trips through the web mappers preserving the canonical fields', () => {
		const task = remoteToTask(fixture, 0);
		// The drag order comes from the canonical field, not the index fallback.
		expect(task.order).toBe(6);
		// The wire instant resolves to the same local calendar day (expected
		// computed through the same helper so the assertion is TZ-stable).
		expect(task.dueDate).toBe(localDateKey(new Date('2026-11-26T12:00:00Z')));
		expect(task.scheduledForToday).toBe(true);
		// Issue #991 S9: the plan decodes into the local day key.
		expect(task.plannedDate).toBe(localDateKey(new Date('2026-11-26T12:00:00Z')));
		expect(task.notes).toBe('Written on the phone, edited on the web');
		expect(task.completedPomodoros).toBe(5);
		expect(task.focusedSeconds).toBe(3600);
		expect(task.energy).toBe('shallow');
		expect(task.subtasks?.map((s) => s.title)).toEqual(['first step', 'second step']);

		// Re-encode: the canonical fields survive the round trip; dueDate stays
		// on the same local calendar day (the UTC hour may shift by timezone),
		// and known server subtasks carry their id so the backend UPDATES
		// instead of re-inserting duplicates.
		const back = taskToRemote(task);
		expect(back.sortOrder).toBe(6);
		expect(back.scheduledForToday).toBe(true);
		expect(back.energyLevel).toBe('shallow');
		expect(localDateKey(new Date(back.dueDate!))).toBe(localDateKey(new Date('2026-11-26T12:00:00Z')));
		expect(back.completedPomodoros).toBe(5);
		expect(back.subTasks?.map((s) => s.id)).toEqual([7, 8]);
		expect(back.subTasks?.map((s) => s.title)).toEqual(['first step', 'second step']);
	});
});
