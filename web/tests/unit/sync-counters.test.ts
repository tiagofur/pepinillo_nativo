import { describe, expect, it } from 'vitest';
import { computeFocusCounters } from '$lib/data/sync/counters';
import { runInitialUpload } from '$lib/data/sync/engine';
import type { FocusSession, Task } from '$lib/domain/entities/types';

/**
 * Issue #998 (S5): a web push derives the focus counters from the completed
 * sessions it knows about (its own + phone sessions arrived via pull), like
 * the phones do — instead of mirroring the stale last-pull snapshot.
 * Web task ids ARE sync ids, so session.taskId matches Task.id directly.
 */

function task(id: string, mirrored: Partial<Task> = {}): Task {
	return {
		id,
		title: `Task ${id}`,
		status: 'active',
		priority: 'none',
		energy: 'shallow',
		estimatedPomodoros: 1,
		list: 'inbox',
		order: 0,
		createdAt: '2026-11-27T00:00:00',
		updatedAt: '2026-11-27T00:00:00',
		focusedSeconds: 999,
		focusedSecondsPomodoro: 999,
		...mirrored
	} as Task;
}

function session(
	id: string,
	taskId: string | null,
	mode: FocusSession['mode'],
	elapsedMs: number,
	status: FocusSession['status'] = 'completed',
	completedAt = '2026-11-27T10:00:00'
): FocusSession {
	return {
		id,
		mode,
		status,
		startedAt: '2026-11-27T09:00:00',
		elapsedMs,
		segmentStartedAt: null,
		targetMs: null,
		taskId,
		journal: '',
		completedAt: status === 'completed' ? completedAt : null,
		createdAt: '2026-11-27T09:00:00',
		updatedAt: '2026-11-27T10:00:00'
	} as FocusSession;
}

describe('computeFocusCounters (#998 S5)', () => {
	it('accumulates per-mode seconds across the task completed sessions', () => {
		const t = task('t1');
		const out = computeFocusCounters([t], [
			session('s1', 't1', 'pomodoro', 90_000),
			session('s2', 't1', 'flowtime', 120_500), // rounds to 121
			session('s3', 't1', 'stopwatch', 45_000)
		]);
		expect(out[0].focusedSeconds).toBe(90 + 121 + 45);
		expect(out[0].focusedSecondsPomodoro).toBe(90);
		expect(out[0].focusedSecondsFlowtime).toBe(121);
		expect(out[0].focusedSecondsTimeblock).toBe(0);
		expect(out[0].focusedSecondsStopwatch).toBe(45);
		expect(out[0].completedFlowtimeSessions).toBe(1);
		expect(out[0].completedTimeblockSessions).toBe(0);
		expect(out[0].completedStopwatchSeconds).toBe(45);
	});

	it('a task without known completed sessions keeps its mirrored counters', () => {
		const t = task('t2', { focusedSeconds: 500, focusedSecondsPomodoro: 500 });
		const out = computeFocusCounters([t], [session('s9', 't1', 'pomodoro', 30_000)]);
		expect(out[0].focusedSeconds).toBe(500);
		expect(out[0].focusedSecondsPomodoro).toBe(500);
		expect(out[0].trackingMode).toBeUndefined();
	});

	it('skipped sessions and other tasks sessions are ignored; trackingMode = latest completed', () => {
		const t = task('t3');
		const out = computeFocusCounters([t], [
			session('s1', 't3', 'stopwatch', 10_000, 'skipped'),
			session('s2', 'other', 'flowtime', 60_000),
			session('s3', 't3', 'timeblock', 20_000, 'completed', '2026-11-27T08:00:00'),
			session('s4', 't3', 'pomodoro', 30_000, 'completed', '2026-11-27T11:00:00')
		]);
		expect(out[0].focusedSeconds).toBe(50);
		expect(out[0].focusedSecondsTimeblock).toBe(20);
		expect(out[0].focusedSecondsPomodoro).toBe(30);
		expect(out[0].trackingMode).toBe('pomodoro');
	});
});

describe('runInitialUpload pushes computed counters (#998 S5 wiring)', () => {
	it('the task payload carries the derived counters, not the stale mirror', async () => {
		let captured: { tasks: Array<Record<string, unknown>> } | null = null;
		const api = {
			async initialUpload(body: never) {
				captured = body;
				return { duplicatesSkipped: 0 };
			}
		} as never;
		await runInitialUpload(api, {
			deviceId: 'dev-1',
			tasks: [task('t1', { focusedSeconds: 999 })],
			sessions: [session('s1', 't1', 'pomodoro', 60_000)],
			prefs: {}
		} as never);
		const sent = (captured as unknown as { tasks: Array<Record<string, unknown>> }).tasks[0];
		expect(sent.focusedSeconds).toBe(60);
		expect(sent.focusedSecondsPomodoro).toBe(60);
		expect(sent.trackingMode).toBe('pomodoro');
	});
});
