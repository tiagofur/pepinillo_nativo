import { describe, expect, it } from 'vitest';
import {
	createIdleSession,
	startSession,
	pauseSession,
	resumeSession,
	skipSession,
	completeSession,
	tickSession,
	recomputeOnVisible,
	setJournal,
	linkTask
} from '$lib/domain/focus/engine';
import type { FocusSession } from '$lib/domain/entities/types';

const T0 = '2026-08-05T10:00:00.000Z';
const T1 = '2026-08-05T10:00:30.000Z'; // +30s
const T2 = '2026-08-05T10:01:00.000Z'; // +60s from T0
const T3 = '2026-08-05T10:01:30.000Z'; // +90s

describe('Focus engine — Pomodoro', () => {
	it('starts a pomodoro with target duration from work minutes', () => {
		const idle = createIdleSession('pomodoro', { workMinutes: 25 });
		const running = startSession(idle, T0);
		expect(running.status).toBe('running');
		expect(running.mode).toBe('pomodoro');
		expect(running.startedAt).toBe(T0);
		expect(running.segmentStartedAt).toBe(T0);
		expect(running.targetMs).toBe(25 * 60 * 1000);
		expect(running.elapsedMs).toBe(0);
	});

	it('ticks wall-clock elapsed while running', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const ticked = tickSession(running, T1);
		expect(ticked.elapsedMs).toBe(30_000);
		expect(ticked.status).toBe('running');
	});

	it('pauses without advancing elapsed during pause gap', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const mid = tickSession(running, T1);
		const paused = pauseSession(mid, T1);
		expect(paused.status).toBe('paused');
		expect(paused.elapsedMs).toBe(30_000);
		expect(paused.segmentStartedAt).toBeNull();

		// time passes while paused — tick must not add pause gap
		const stillPaused = tickSession(paused, T2);
		expect(stillPaused.elapsedMs).toBe(30_000);
	});

	it('resumes and continues accumulating from prior elapsed', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const paused = pauseSession(tickSession(running, T1), T1);
		const resumed = resumeSession(paused, T2);
		expect(resumed.status).toBe('running');
		expect(resumed.segmentStartedAt).toBe(T2);
		const after = tickSession(resumed, T3);
		// 30s before pause + 30s after resume
		expect(after.elapsedMs).toBe(60_000);
	});

	it('skips a running session', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const skipped = skipSession(running, T1);
		expect(skipped.status).toBe('skipped');
		expect(skipped.completedAt).toBe(T1);
		expect(skipped.elapsedMs).toBe(30_000);
	});

	it('completes when elapsed reaches target', () => {
		const idle = createIdleSession('pomodoro', { workMinutes: 1 }); // 60s target
		const running = startSession(idle, T0);
		const done = tickSession(running, T2); // +60s
		expect(done.status).toBe('completed');
		expect(done.elapsedMs).toBe(60_000);
		expect(done.completedAt).toBe(T2);
	});

	it('can complete manually', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const done = completeSession(tickSession(running, T1), T1);
		expect(done.status).toBe('completed');
		expect(done.completedAt).toBe(T1);
	});
});

describe('Focus engine — Stopwatch', () => {
	it('starts without target duration', () => {
		const running = startSession(createIdleSession('stopwatch'), T0);
		expect(running.mode).toBe('stopwatch');
		expect(running.targetMs).toBeNull();
		expect(running.status).toBe('running');
	});

	it('counts up without auto-complete', () => {
		const running = startSession(createIdleSession('stopwatch'), T0);
		const ticked = tickSession(running, T2);
		expect(ticked.elapsedMs).toBe(60_000);
		expect(ticked.status).toBe('running');
	});
});

describe('Focus engine — visibility recompute', () => {
	it('recomputes elapsed from wall-clock on visible without double-count', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		// UI was frozen; on visible we recompute from segment start
		const recomputed = recomputeOnVisible(running, T2);
		expect(recomputed.elapsedMs).toBe(60_000);
		expect(recomputed.status).toBe('running');
	});

	it('does not advance paused session on visible', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const paused = pauseSession(tickSession(running, T1), T1);
		const still = recomputeOnVisible(paused, T3);
		expect(still.elapsedMs).toBe(30_000);
		expect(still.status).toBe('paused');
	});
});

describe('Focus engine — journal and task link', () => {
	it('sets journal text', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const withNote = setJournal(running, 'Deep work on gates');
		expect(withNote.journal).toBe('Deep work on gates');
	});

	it('links optional task id', () => {
		const running = startSession(createIdleSession('stopwatch'), T0);
		const linked = linkTask(running, 'task-1');
		expect(linked.taskId).toBe('task-1');
		const unlinked = linkTask(linked, null);
		expect(unlinked.taskId).toBeNull();
	});
});

describe('Focus engine — invalid transitions', () => {
	it('does not start an already running session', () => {
		const running = startSession(createIdleSession('pomodoro', { workMinutes: 25 }), T0);
		const again = startSession(running, T1);
		expect(again.startedAt).toBe(T0);
		expect(again.segmentStartedAt).toBe(T0);
	});

	it('pause on idle is a no-op', () => {
		const idle = createIdleSession('pomodoro', { workMinutes: 25 });
		const paused = pauseSession(idle, T0);
		expect(paused.status).toBe('idle');
	});
});

// type-only guard so unused import does not trip lint in some configs
void (null as unknown as FocusSession);
