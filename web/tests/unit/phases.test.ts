import { describe, expect, it } from 'vitest';
import {
	adjustBlockMinutes,
	advanceAfterBreak,
	advanceAfterCompletedWork,
	breakAfterWork,
	flowtimeBreakMinutes,
	isBreakPhase,
	midpointReached,
	phaseDurationMs,
	rollPomodoroNumber,
	skipCreditFraction
} from '$lib/domain/focus/phases';
import { DEFAULT_PREFERENCES } from '$lib/domain/entities/types';

const prefs = { ...DEFAULT_PREFERENCES };

describe('flowtimeBreakMinutes', () => {
	it('follows the native formula boundaries', () => {
		expect(flowtimeBreakMinutes(0)).toBe(5);
		expect(flowtimeBreakMinutes(24)).toBe(5);
		expect(flowtimeBreakMinutes(25)).toBe(8);
		expect(flowtimeBreakMinutes(49)).toBe(8);
		expect(flowtimeBreakMinutes(50)).toBe(10);
		expect(flowtimeBreakMinutes(89)).toBe(10);
		expect(flowtimeBreakMinutes(90)).toBe(15);
		expect(flowtimeBreakMinutes(120)).toBe(15);
	});
});

describe('pomodoro cycle', () => {
	it('gives short breaks until the cycle is complete, then a long break', () => {
		expect(breakAfterWork(1, prefs)).toBe('shortBreak');
		expect(breakAfterWork(3, prefs)).toBe('shortBreak');
		expect(breakAfterWork(4, prefs)).toBe('longBreak');
	});

	it('advances pomodoro number after each completed work phase', () => {
		let cycle = { pomodoroNumber: 1, completedInCycle: 0 };
		let nextPhase: string = advanceAfterCompletedWork(cycle, prefs).nextPhase;
		expect(nextPhase).toBe('shortBreak');

		// Complete the whole cycle one work phase at a time.
		for (let i = 0; i < 4; i += 1) {
			const r = advanceAfterCompletedWork(cycle, prefs);
			cycle = r.cycle;
			nextPhase = r.nextPhase;
		}
		expect(nextPhase).toBe('longBreak');
		expect(cycle.pomodoroNumber).toBe(5);
		expect(cycle.completedInCycle).toBe(4);
	});

	it('resets the cycle after a long break only', () => {
		const state = { pomodoroNumber: 5, completedInCycle: 4 };
		expect(advanceAfterBreak(state, 'longBreak').completedInCycle).toBe(0);
		expect(advanceAfterBreak(state, 'shortBreak').completedInCycle).toBe(4);
	});

	it('rolls the daily pomodoro number at day change', () => {
		const state = { pomodoroNumber: 6, completedInCycle: 2 };
		expect(rollPomodoroNumber(state, '2026-11-15', '2026-11-16')).toEqual({
			pomodoroNumber: 1,
			completedInCycle: 0
		});
		expect(rollPomodoroNumber(state, '2026-11-16', '2026-11-16')).toBe(state);
	});
});

describe('phase durations', () => {
	it('pomodoro phases use configured durations', () => {
		expect(phaseDurationMs('work', 'pomodoro', prefs)).toBe(25 * 60_000);
		expect(phaseDurationMs('shortBreak', 'pomodoro', prefs)).toBe(5 * 60_000);
		expect(phaseDurationMs('longBreak', 'pomodoro', prefs)).toBe(15 * 60_000);
	});

	it('flowtime work is count-up (null target) and break uses formula', () => {
		expect(phaseDurationMs('work', 'flowtime', prefs)).toBeNull();
		expect(phaseDurationMs('shortBreak', 'flowtime', prefs, 30 * 60_000)).toBe(8 * 60_000);
	});

	it('timeblock uses the configured block length; stopwatch has none', () => {
		expect(phaseDurationMs('work', 'timeblock', prefs)).toBe(60 * 60_000);
		expect(phaseDurationMs('shortBreak', 'timeblock', prefs)).toBe(0);
		expect(phaseDurationMs('work', 'stopwatch', prefs)).toBe(0);
	});
});

describe('skip credit', () => {
	it('computes capped partial credit', () => {
		expect(skipCreditFraction(0, 25 * 60_000)).toBe(0);
		expect(skipCreditFraction(12.5 * 60_000, 25 * 60_000)).toBeCloseTo(0.5);
		expect(skipCreditFraction(30 * 60_000, 25 * 60_000)).toBe(1);
		expect(skipCreditFraction(10_000, null)).toBe(0);
	});
});

describe('timeblock helpers', () => {
	it('adjusts between 5 and 180 minutes', () => {
		expect(adjustBlockMinutes(60, 15)).toBe(75);
		expect(adjustBlockMinutes(60, -15)).toBe(45);
		expect(adjustBlockMinutes(5, -15)).toBe(5);
		expect(adjustBlockMinutes(180, 15)).toBe(180);
	});

	it('detects the midpoint once reached', () => {
		expect(midpointReached(29 * 60_000, 60 * 60_000)).toBe(false);
		expect(midpointReached(30 * 60_000, 60 * 60_000)).toBe(true);
	});
});

describe('phase helpers', () => {
	it('classifies breaks', () => {
		expect(isBreakPhase('work')).toBe(false);
		expect(isBreakPhase('shortBreak')).toBe(true);
		expect(isBreakPhase('longBreak')).toBe(true);
	});
});
