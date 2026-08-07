import type {
	FocusMode,
	FocusSession,
	Preferences,
	Task,
	TaskEnergy,
	TaskList,
	TaskPriority,
	TaskStatus
} from '$lib/domain/entities/types';
import type { RemoteFocusSession, RemoteTask, UserPreference } from '$lib/data/remote/types';

const PRIORITY_TO_INT: Record<TaskPriority, number> = {
	low: 1,
	medium: 2,
	high: 3
};

const INT_TO_PRIORITY: Record<number, TaskPriority> = {
	1: 'low',
	2: 'medium',
	3: 'high'
};

const VALID_LISTS = new Set<TaskList>(['inbox', 'today', 'upcoming']);
const VALID_ENERGIES = new Set<TaskEnergy>(['low', 'medium', 'high']);
const VALID_MODES = new Set<FocusMode>(['pomodoro', 'stopwatch', 'flowtime', 'timeblock']);

export function taskToRemote(task: Task): RemoteTask {
	return {
		syncId: task.id,
		title: task.title,
		energyLevel: task.energy,
		isFinished: task.status === 'completed',
		priority: PRIORITY_TO_INT[task.priority] ?? 0,
		estimatedPomodoros: task.estimatedPomodoros,
		isDeleted: task.status === 'archived',
		updatedAt: task.updatedAt,
		createdDate: task.createdAt,
		category: task.list
	};
}

export function sessionToRemote(session: FocusSession): RemoteFocusSession | null {
	if (session.status !== 'completed' && session.status !== 'skipped') return null;
	if (!session.startedAt) return null;
	const endedAt = session.completedAt ?? session.updatedAt;
	const elapsedSec = Math.max(0, Math.round(session.elapsedMs / 1000));
	const durationSec =
		session.targetMs != null ? Math.max(0, Math.round(session.targetMs / 1000)) : elapsedSec;
	return {
		id: session.id,
		taskSyncId: session.taskId,
		startedAt: session.startedAt,
		endedAt,
		mode: session.mode,
		phase: 'work',
		durationSeconds: durationSec,
		elapsedSeconds: elapsedSec,
		pauseCount: 0,
		totalPauseSeconds: 0,
		wasCompleted: session.status === 'completed',
		journalNote: session.journal || '',
		createdAt: session.createdAt,
		updatedAt: session.updatedAt
	};
}

export function prefsToRemoteSettings(prefs: Preferences): UserPreference[] {
	const now = new Date().toISOString();
	return [
		{ key: 'locale', value: prefs.locale, updatedAt: now },
		{ key: 'theme', value: prefs.theme, updatedAt: now },
		{ key: 'autoStartNext', value: String(prefs.autoStartNext), updatedAt: now },
		{ key: 'pomodoroWorkMinutes', value: String(prefs.pomodoroWorkMinutes), updatedAt: now },
		{ key: 'pomodoroBreakMinutes', value: String(prefs.pomodoroBreakMinutes), updatedAt: now }
	];
}

/**
 * Reverse-map a backend task to the local Task shape. Used by the pull/merge
 * path to apply server state into IndexedDB. `order` is not carried by the
 * wire format, so the caller must assign it (typically by stable index).
 */
export function remoteToTask(rt: RemoteTask, order = 0): Task {
	const status: TaskStatus = rt.isDeleted
		? 'archived'
		: rt.isFinished
			? 'completed'
			: 'active';
	const category = (rt.category ?? 'inbox') as TaskList;
	const energyRaw = (rt.energyLevel ?? 'medium') as TaskEnergy;
	return {
		id: rt.syncId,
		title: rt.title ?? '',
		status,
		priority: INT_TO_PRIORITY[rt.priority] ?? 'medium',
		energy: VALID_ENERGIES.has(energyRaw) ? energyRaw : 'medium',
		estimatedPomodoros: rt.estimatedPomodoros ?? 0,
		list: VALID_LISTS.has(category) ? category : 'inbox',
		order,
		createdAt: rt.createdDate ?? rt.updatedAt,
		updatedAt: rt.updatedAt
	};
}

/**
 * Reverse-map a backend focus session to the local FocusSession shape.
 * Backend only stores terminal sessions (completed/skipped); running state is
 * per-device and not reconstructed from the server.
 */
export function remoteToSession(rs: RemoteFocusSession): FocusSession {
	const status: FocusSession['status'] = rs.wasCompleted ? 'completed' : 'skipped';
	const modeRaw = (rs.mode ?? 'pomodoro') as FocusMode;
	const isCountdown = modeRaw === 'pomodoro' || modeRaw === 'timeblock';
	return {
		id: rs.id,
		mode: VALID_MODES.has(modeRaw) ? modeRaw : 'pomodoro',
		status,
		startedAt: rs.startedAt,
		elapsedMs: Math.max(0, rs.elapsedSeconds) * 1000,
		segmentStartedAt: null,
		targetMs: isCountdown && rs.durationSeconds > 0 ? rs.durationSeconds * 1000 : null,
		taskId: rs.taskSyncId ?? null,
		journal: rs.journalNote ?? '',
		completedAt: rs.endedAt ?? null,
		createdAt: rs.createdAt ?? rs.startedAt,
		updatedAt: rs.updatedAt
	};
}

/**
 * Map known backend preference rows back onto a Preferences partial. Unknown
 * keys (native-only prefs) are ignored. `onboardingCompleted` is device-local
 * and never overwritten from the server.
 */
export function remoteSettingsToPrefs(settings: UserPreference[]): Partial<Preferences> {
	const out: Partial<Preferences> = {};
	const str = (v: string): string => v;
	const num = (v: string): number => {
		const n = Number(v);
		return Number.isFinite(n) ? n : NaN;
	};
	const bool = (v: string): boolean => v === 'true';
	for (const row of settings) {
		switch (row.key) {
			case 'locale':
				out.locale = str(row.value) as Preferences['locale'];
				break;
			case 'theme':
				out.theme = str(row.value) as Preferences['theme'];
				break;
			case 'autoStartNext':
				out.autoStartNext = bool(row.value);
				break;
			case 'pomodoroWorkMinutes': {
				const n = num(row.value);
				if (!Number.isNaN(n)) out.pomodoroWorkMinutes = n;
				break;
			}
			case 'pomodoroBreakMinutes': {
				const n = num(row.value);
				if (!Number.isNaN(n)) out.pomodoroBreakMinutes = n;
				break;
			}
		}
	}
	return out;
}
