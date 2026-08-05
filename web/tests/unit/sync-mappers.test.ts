import { describe, expect, it } from 'vitest';
import { sessionToRemote, taskToRemote } from '$lib/data/sync/mappers';
import type { FocusSession, Task } from '$lib/domain/entities/types';

describe('sync mappers', () => {
	it('maps task id to syncId', () => {
		const task: Task = {
			id: 'uuid-1',
			title: 'Ship web',
			status: 'active',
			priority: 'high',
			energy: 'high',
			estimatedPomodoros: 2,
			list: 'today',
			order: 0,
			createdAt: '2026-08-05T00:00:00.000Z',
			updatedAt: '2026-08-05T01:00:00.000Z'
		};
		const remote = taskToRemote(task);
		expect(remote.syncId).toBe('uuid-1');
		expect(remote.title).toBe('Ship web');
		expect(remote.priority).toBe(3);
		expect(remote.isFinished).toBe(false);
	});

	it('maps completed session only', () => {
		const idle: FocusSession = {
			id: 's1',
			mode: 'pomodoro',
			status: 'idle',
			startedAt: null,
			elapsedMs: 0,
			segmentStartedAt: null,
			targetMs: 1500000,
			taskId: null,
			journal: '',
			completedAt: null,
			createdAt: '2026-08-05T00:00:00.000Z',
			updatedAt: '2026-08-05T00:00:00.000Z'
		};
		expect(sessionToRemote(idle)).toBeNull();

		const done: FocusSession = {
			...idle,
			status: 'completed',
			startedAt: '2026-08-05T10:00:00.000Z',
			elapsedMs: 60000,
			completedAt: '2026-08-05T10:01:00.000Z',
			journal: 'deep work'
		};
		const remote = sessionToRemote(done);
		expect(remote?.elapsedSeconds).toBe(60);
		expect(remote?.wasCompleted).toBe(true);
		expect(remote?.journalNote).toBe('deep work');
	});
});
