/** Shared domain entities for Free local web client (W1). */

export type FocusMode = 'pomodoro' | 'stopwatch' | 'flowtime' | 'timeblock';

export type TaskPriority = 'none' | 'low' | 'medium' | 'high';
export type TaskEnergy = 'deep' | 'shallow' | 'admin';
export type TaskList = 'inbox' | 'today' | 'upcoming';

export type TaskStatus = 'active' | 'completed' | 'archived';

/** Subtask embedded in the Task record (Pepinillo+ feature). */
export interface SubTask {
	id: string;
	title: string;
	isCompleted: boolean;
	sortOrder: number;
	createdAt: string;
}

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
	/* ---- W3 parity fields (Room v14 / SchemaV6) ---- */
	notes?: string;
	completedPomodoros?: number;
	dueDate?: string | null;
	scheduledForToday?: boolean;
	completedAt?: string | null;
	subtasks?: SubTask[];
	recurrenceRule?: string | null;
	/** Recurring series: when this occurrence was last completed. */
	lastCompletedAt?: string | null;
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
	/* ---- W2 record enrichment (additive; sync mappers ignore extras) ---- */
	phase?: FocusPhase;
	satisfactionRating?: 1 | 2 | 3 | 4 | 5;
	interruptions?: number;
	pauseCount?: number;
	totalPauseMs?: number;
}

export type ThemePreference = 'system' | 'light' | 'dark';
export type LocaleCode = 'en' | 'es' | 'pt';

/** Pomodoro/TImeBlock work phases. Breaks exist only inside a mode flow. */
export type FocusPhase = 'work' | 'shortBreak' | 'longBreak';

export type CompletionSoundName = 'classic' | 'chime' | 'bell' | 'digital' | 'woodblock';
export type SoundscapeName =
	| 'none'
	| 'rain'
	| 'forest'
	| 'cafe'
	| 'whiteNoise'
	| 'ocean'
	| 'fireplace'
	| 'binaural'
	| 'lofi';

export interface Preferences {
	locale: LocaleCode;
	theme: ThemePreference;
	onboardingCompleted: boolean;
	/** Auto-start next work/break segment (Pomodoro) */
	autoStartNext: boolean;
	pomodoroWorkMinutes: number;
	pomodoroBreakMinutes: number;
	/* ---- W2 focus parity (defaults mirror the native apps) ---- */
	pomodoroLongBreakMinutes: number;
	pomodoroSessionsBeforeLongBreak: number;
	autoStartBreaks: boolean;
	autoStartWork: boolean;
	flowtimeMinSessionMinutes: number;
	timeBlockMinutes: number;
	timeBlockMidpointCheckIn: boolean;
	soundEnabled: boolean;
	completionSound: CompletionSoundName;
	soundscape: SoundscapeName;
	soundscapeVolume: number; // 0..1
	hapticsEnabled: boolean;
	keepScreenOn: boolean;
	showJournalAfterSession: boolean;
	adhdFriendlyEnabled: boolean;
	notificationsEnabled: boolean;
	/* ---- macOS parity (MacSettingsView / iOS SettingsView) ---- */
	defaultSection: 'focus' | 'plan' | 'dashboard';
	dailyReminderEnabled: boolean;
	dailyReminderHour: number;
	dailyReminderMinute: number;
	weeklyRecapEnabled: boolean;
	celebrateRecordsEnabled: boolean;
	analyticsOptIn: boolean;
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
	pomodoroBreakMinutes: 5,
	pomodoroLongBreakMinutes: 15,
	pomodoroSessionsBeforeLongBreak: 4,
	autoStartBreaks: true,
	autoStartWork: false,
	flowtimeMinSessionMinutes: 5,
	timeBlockMinutes: 60,
	timeBlockMidpointCheckIn: false,
	soundEnabled: true,
	completionSound: 'classic',
	soundscape: 'none',
	soundscapeVolume: 0.5,
	hapticsEnabled: false,
	keepScreenOn: false,
	showJournalAfterSession: true,
	adhdFriendlyEnabled: false,
	notificationsEnabled: false,
	defaultSection: 'focus',
	dailyReminderEnabled: false,
	dailyReminderHour: 9,
	dailyReminderMinute: 0,
	weeklyRecapEnabled: false,
	celebrateRecordsEnabled: true,
	analyticsOptIn: false
};
