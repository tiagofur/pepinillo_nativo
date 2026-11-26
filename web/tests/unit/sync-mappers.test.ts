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
import { localDateKey } from '$lib/domain/tasks/recurrence';

describe('sync mappers', () => {
	it('maps task id to syncId', () => {
		const task: Task = {
			id: 'uuid-1',
			title: 'Ship web',
			status: 'active',
			priority: 'high',
			energy: 'deep',
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
			energy: 'deep',
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

describe('canonical task fields (#989 PR-C, S6)', () => {
	const base: Task = {
		id: 'w1',
		title: 'Web task',
		status: 'active',
		priority: 'none',
		energy: 'shallow',
		estimatedPomodoros: 1,
		list: 'inbox',
		order: 2,
		createdAt: '2026-11-20T08:00:00.000Z',
		updatedAt: '2026-11-20T09:00:00.000Z'
	};

	it('upload carries due/completed/today/order/notes/counters and subtasks', () => {
		const task: Task = {
			...base,
			dueDate: '2026-11-21',
			completedAt: '2026-11-20T10:00:00.000Z',
			scheduledForToday: true,
			notes: 'context notes',
			completedPomodoros: 4,
			focusedSeconds: 7200,
			focusedSecondsPomodoro: 7200,
			completedFlowtimeSessions: 2,
			trackingMode: 'flowtime',
			subtasks: [
				{ id: 's1', title: 'first', isCompleted: true, sortOrder: 0, createdAt: '2026-11-20T08:00:00.000Z' },
				{ id: 's2', title: 'second', isCompleted: false, sortOrder: 1, createdAt: '2026-11-20T08:00:00.000Z' }
			]
		};
		const remote = taskToRemote(task);
		// dueDate is a local day key on web: it must travel as the UTC-noon
		// instant of that local day so the server day matches every client.
		expect(remote.dueDate).toBe(new Date('2026-11-21T12:00:00').toISOString());
		expect(remote.completedAt).toBe('2026-11-20T10:00:00.000Z');
		expect(remote.scheduledForToday).toBe(true);
		expect(remote.sortOrder).toBe(2);
		expect(remote.description).toBe('context notes');
		expect(remote.completedPomodoros).toBe(4);
		expect(remote.focusedSeconds).toBe(7200);
		expect(remote.trackingMode).toBe('flowtime');
		expect(remote.subTasks?.map((s) => s.title)).toEqual(['first', 'second']);
		expect(remote.subTasks?.[0]?.isFinished).toBe(true);
	});

	it('upload omits subTasks when empty so server subtasks are never wiped', () => {
		const remote = taskToRemote({ ...base });
		expect(remote.subTasks).toBeUndefined();
		// Empty trackingMode is invalid server-side → the backend preserves
		// the phone-set tracking mode instead of resetting it to pomodoro.
		expect(remote.trackingMode).toBe('');
	});

	it('download maps canonical fields, order from sortOrder, and subtasks', () => {
		const rt: RemoteTask = {
			id: 7,
			syncId: 'srv-1',
			title: 'From phone',
			energyLevel: 'admin',
			isFinished: false,
			priority: 2,
			estimatedPomodoros: 2,
			completedPomodoros: 5,
			isDeleted: false,
			updatedAt: '2026-11-25T08:00:00.000Z',
			createdDate: '2026-11-20T08:00:00.000Z',
			category: 'inbox',
			dueDate: '2026-11-26T12:00:00.000Z',
			completedAt: null,
			scheduledForToday: true,
			sortOrder: 6,
			description: 'phone notes',
			trackingMode: 'pomodoro',
			focusedSeconds: 3600,
			focusedSecondsPomodoro: 3600,
			completedFlowtimeSessions: 1,
			subTasks: [{ id: 3, taskId: 7, title: 'phone sub', isFinished: true }]
		};
		const task = remoteToTask(rt, 0);
		expect(task.order).toBe(6); // canonical drag order beats the index fallback
		expect(task.dueDate).toBe(localDateKey(new Date('2026-11-26T12:00:00.000Z')));
		expect(task.scheduledForToday).toBe(true);
		expect(task.notes).toBe('phone notes');
		expect(task.completedPomodoros).toBe(5);
		expect(task.focusedSeconds).toBe(3600);
		expect(task.trackingMode).toBe('pomodoro');
		expect(task.subtasks?.[0]?.title).toBe('phone sub');
		expect(task.subtasks?.[0]?.isCompleted).toBe(true);
		expect(task.energy).toBe('admin');
	});

	it('download falls back to the index order when legacy payloads omit sortOrder', () => {
		const rt: RemoteTask = {
			syncId: 'x',
			isFinished: false,
			priority: 0,
			estimatedPomodoros: 0,
			isDeleted: false,
			updatedAt: '2026-01-01T00:00:00.000Z'
		};
		expect(remoteToTask(rt, 3).order).toBe(3);
	});
});
