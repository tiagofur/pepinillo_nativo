/**
 * Focus phase machine — pure, mirror of the native strategies:
 * iOS Features/Focus/Modes/{Pomodoro,Flowtime,TimeBlock,Stopwatch}Strategy.swift
 * and android FocusEngine.onPhaseComplete / FocusMode.
 *
 * The recovered engine (engine.ts) owns wall-clock timing of ONE segment;
 * this module owns WHICH segment comes next, holds, skips and credit.
 */

import type { FocusMode, FocusPhase, Preferences } from '$lib/domain/entities/types';

export const PHASE_COLORS: Record<FocusPhase, string> = {
	work: 'var(--mode-pomodoro)',
	shortBreak: 'var(--mode-flowtime)',
	longBreak: 'var(--mode-timeblock)'
};

export interface PomodoroCycleState {
	/** 1-based daily work-phase counter (persisted across days, reset daily). */
	pomodoroNumber: number;
	/** Work phases completed inside the current cycle (reset after long break). */
	completedInCycle: number;
}

export function pomodoroConfigFrom(prefs: Preferences): {
	workMs: number;
	breakMs: number;
	longBreakMs: number;
	beforeLongBreak: number;
} {
	return {
		workMs: prefs.pomodoroWorkMinutes * 60_000,
		breakMs: prefs.pomodoroBreakMinutes * 60_000,
		longBreakMs: prefs.pomodoroLongBreakMinutes * 60_000,
		beforeLongBreak: Math.max(1, prefs.pomodoroSessionsBeforeLongBreak)
	};
}

export function phaseDurationMs(
	phase: FocusPhase,
	mode: FocusMode,
	prefs: Preferences,
	flowWorkMs = 0
): number {
	if (mode === 'pomodoro') {
		const cfg = pomodoroConfigFrom(prefs);
		if (phase === 'work') return cfg.workMs;
		if (phase === 'shortBreak') return cfg.breakMs;
		return cfg.longBreakMs;
	}
	if (mode === 'flowtime') {
		// Break countdown by formula; work itself is open-ended (count-up).
		if (phase === 'work') return null as unknown as number; // caller treats as count-up
		return flowtimeBreakMinutes(Math.round(flowWorkMs / 60_000)) * 60_000;
	}
	if (mode === 'timeblock') {
		if (phase === 'work') return prefs.timeBlockMinutes * 60_000;
		return 0; // no breaks in timeblock
	}
	return 0; // stopwatch: no phases beyond work
}

/**
 * Flowtime break formula (native parity): <25→5, <50→8, <90→10, ≥90→15.
 */
export function flowtimeBreakMinutes(workMinutes: number): number {
	if (workMinutes < 25) return 5;
	if (workMinutes < 50) return 8;
	if (workMinutes < 90) return 10;
	return 15;
}

/**
 * Which break follows the Nth completed work phase of a pomodoro cycle.
 */
export function breakAfterWork(completedInCycle: number, prefs: Preferences): FocusPhase {
	const { beforeLongBreak } = pomodoroConfigFrom(prefs);
	return completedInCycle >= beforeLongBreak ? 'longBreak' : 'shortBreak';
}

/**
 * Advance after a COMPLETED work phase (full credit).
 * Returns the next phase to schedule and the cycle updates.
 */
export function advanceAfterCompletedWork(
	state: PomodoroCycleState,
	prefs: Preferences
): { nextPhase: FocusPhase; cycle: PomodoroCycleState } {
	const completedInCycle = state.completedInCycle + 1;
	return {
		nextPhase: breakAfterWork(completedInCycle, prefs),
		cycle: { ...state, completedInCycle, pomodoroNumber: state.pomodoroNumber + 1 }
	};
}

/**
 * Advance after a break completes (or is skipped).
 * A long break closes the cycle; short/none keep accumulating.
 */
export function advanceAfterBreak(
	state: PomodoroCycleState,
	completedPhase: FocusPhase
): PomodoroCycleState {
	if (completedPhase === 'longBreak') {
		return { ...state, completedInCycle: 0 };
	}
	return state;
}

/**
 * Partial credit fraction for a skipped work phase (0..1], mirroring the
 * native `phaseSkipped` record with credit.
 */
export function skipCreditFraction(elapsedMs: number, targetMs: number | null): number {
	if (targetMs == null || targetMs <= 0) return 0;
	return Math.min(1, Math.max(0, elapsedMs / targetMs));
}

/** Pomodoro number resets at day rollover (native `resetForNewDay`). */
export function rollPomodoroNumber(
	state: PomodoroCycleState,
	lastActivityDateKey: string,
	todayDateKey: string
): PomodoroCycleState {
	if (lastActivityDateKey !== todayDateKey) {
		return { ...state, pomodoroNumber: 1, completedInCycle: 0 };
	}
	return state;
}

export function isBreakPhase(phase: FocusPhase): boolean {
	return phase === 'shortBreak' || phase === 'longBreak';
}

/**
 * TimeBlock ±adjust helpers (native buttons flank Start).
 */
export function adjustBlockMinutes(currentMinutes: number, deltaMinutes: number): number {
	return Math.min(180, Math.max(5, currentMinutes + deltaMinutes));
}

/**
 * Midpoint moment for TimeBlock check-in (fraction 0.5), used by the
 * controller to raise `midpointReached` once per block.
 */
export function midpointReached(elapsedMs: number, targetMs: number): boolean {
	return targetMs > 0 && elapsedMs >= targetMs / 2;
}
