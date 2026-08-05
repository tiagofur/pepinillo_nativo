/** Shared domain entities for Free local web client (W1). */

export type FocusMode = 'pomodoro' | 'stopwatch' | 'flowtime' | 'timeblock';

export type TaskPriority = 'low' | 'medium' | 'high';
export type TaskEnergy = 'low' | 'medium' | 'high';
export type TaskList = 'inbox' | 'today' | 'upcoming';

export type TaskStatus = 'active' | 'completed' | 'archived';

export interface Task {
	id: string;
	title: string;
	status: TaskStatus;
	priority: TaskPriority;
	energy: TaskEnergy;
	estimatedPomodoros: number;
	list: TaskList;
	order: number;
	createdAt: string;
	updatedAt: string;
	/** Free: always empty / undefined */
	subtasks?: never;
	recurrence?: never;
}

export type SessionStatus = 'idle' | 'running' | 'paused' | 'completed' | 'skipped';

export interface FocusSession {
	id: string;
	mode: FocusMode;
	status: SessionStatus;
	/** ISO wall-clock when session first started */
	startedAt: string | null;
	/** Accumulated active ms while running (excludes pause gaps) */
	elapsedMs: number;
	/** Wall-clock ms when current running segment began */
	segmentStartedAt: string | null;
	/** Target duration for countdown modes (pomodoro work/break) */
	targetMs: number | null;
	taskId: string | null;
	journal: string;
	completedAt: string | null;
	createdAt: string;
	updatedAt: string;
}

export type ThemePreference = 'system' | 'light' | 'dark';
export type LocaleCode = 'en' | 'es' | 'pt';

export interface Preferences {
	locale: LocaleCode;
	theme: ThemePreference;
	onboardingCompleted: boolean;
	/** Auto-start next work/break segment (Pomodoro) */
	autoStartNext: boolean;
	pomodoroWorkMinutes: number;
	pomodoroBreakMinutes: number;
}

export interface DeviceMeta {
	deviceId: string;
	schemaVersion: number;
}

export const FREE_MAX_ACTIVE_TASKS = 3;
export const FREE_ANALYTICS_DAYS = 7;
export const FREE_MODES: readonly FocusMode[] = ['pomodoro', 'stopwatch'] as const;
export const PREMIUM_MODES: readonly FocusMode[] = ['flowtime', 'timeblock'] as const;

export const DEFAULT_PREFERENCES: Preferences = {
	locale: 'en',
	theme: 'system',
	onboardingCompleted: false,
	autoStartNext: false,
	pomodoroWorkMinutes: 25,
	pomodoroBreakMinutes: 5
};
