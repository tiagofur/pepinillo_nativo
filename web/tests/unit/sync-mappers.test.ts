import { describe, expect, it } from 'vitest';
import {
	remoteToSession,
	remoteToTask,
	remoteSettingsToPrefs,
	sessionToRemote,
	taskToRemote
} from '$lib/data/sync/mappers';
import type { FocusSession, Task } from '$lib/domain/entities/types';
import type { RemoteFocusSession, RemoteTask } from '$lib/data/remote/types';

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

describe('inverse mappers', () => {
	it('round-trips a task through taskToRemote → remoteToTask', () => {
		const task: Task = {
			id: 'uuid-9',
			title: 'Round trip',
			status: 'active',
			priority: 'high',
			energy: 'deep' as Task['energy'],
			estimatedPomodoros: 3,
			list: 'today',
			order: 4,
			createdAt: '2026-08-05T00:00:00.000Z',
			updatedAt: '2026-08-05T01:00:00.000Z'
		};
		const back = remoteToTask(taskToRemote(task), 4);
		expect(back.id).toBe(task.id);
		expect(back.title).toBe(task.title);
		expect(back.priority).toBe('high');
		expect(back.list).toBe('today');
		expect(back.estimatedPomodoros).toBe(3);
		expect(back.order).toBe(4);
	});

	it('maps remote isFinished/isDeleted to local status', () => {
		const finished: RemoteTask = {
			syncId: 'a',
			title: 'done',
			isFinished: true,
			priority: 2,
			estimatedPomodoros: 1,
			isDeleted: false,
			updatedAt: '2026-08-05T00:00:00.000Z',
			category: 'today'
		};
		expect(remoteToTask(finished).status).toBe('completed');

		const deleted: RemoteTask = { ...finished, isFinished: false, isDeleted: true };
		expect(remoteToTask(deleted).status).toBe('archived');
	});

	it('round-trips a completed session through sessionToRemote → remoteToSession', () => {
		const session: FocusSession = {
			id: 's2',
			mode: 'pomodoro',
			status: 'completed',
			startedAt: '2026-08-05T10:00:00.000Z',
			elapsedMs: 1500000,
			segmentStartedAt: null,
			targetMs: 1500000,
			taskId: 't1',
			journal: 'flow',
			completedAt: '2026-08-05T10:25:00.000Z',
			createdAt: '2026-08-05T10:00:00.000Z',
			updatedAt: '2026-08-05T10:25:00.000Z'
		};
		const remote = sessionToRemote(session)!;
		const back = remoteToSession(remote);
		expect(back.id).toBe('s2');
		expect(back.status).toBe('completed');
		expect(back.elapsedMs).toBe(1500000);
		expect(back.targetMs).toBe(1500000);
		expect(back.taskId).toBe('t1');
		expect(back.journal).toBe('flow');
	});

	it('remoteToSession nulls targetMs for stopwatch mode', () => {
		const rs: RemoteFocusSession = {
			id: 's3',
			startedAt: '2026-08-05T11:00:00.000Z',
			mode: 'stopwatch',
			phase: 'freeform',
			durationSeconds: 0,
			elapsedSeconds: 600,
			pauseCount: 0,
			totalPauseSeconds: 0,
			wasCompleted: true,
			journalNote: '',
			updatedAt: '2026-08-05T11:10:00.000Z'
		};
		const back = remoteToSession(rs);
		expect(back.targetMs).toBeNull();
		expect(back.elapsedMs).toBe(600_000);
	});

	it('remoteSettingsToPrefs reads known keys and ignores unknown', () => {
		const partial = remoteSettingsToPrefs([
			{ key: 'locale', value: 'es' },
			{ key: 'pomodoroWorkMinutes', value: '45' },
			{ key: 'autoStartNext', value: 'true' },
			{ key: 'someNativeOnlyKey', value: 'ignored' }
		]);
		expect(partial.locale).toBe('es');
		expect(partial.pomodoroWorkMinutes).toBe(45);
		expect(partial.autoStartNext).toBe(true);
		expect(partial.onboardingCompleted).toBeUndefined();
		expect((partial as unknown as Record<string, unknown>).someNativeOnlyKey).toBeUndefined();
	});
});
