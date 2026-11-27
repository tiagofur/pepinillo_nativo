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
import { localDateKey } from '$lib/domain/tasks/recurrence';

const PRIORITY_TO_INT: Record<TaskPriority, number> = {
	none: 0,
	low: 1,
	medium: 2,
	high: 3
};

const INT_TO_PRIORITY: Record<number, TaskPriority> = {
	0: 'none',
	1: 'low',
	2: 'medium',
	3: 'high'
};

const VALID_LISTS = new Set<TaskList>(['inbox', 'today', 'upcoming']);
const VALID_ENERGIES = new Set<TaskEnergy>(['deep', 'shallow', 'admin']);
const VALID_MODES = new Set<FocusMode>(['pomodoro', 'stopwatch', 'flowtime', 'timeblock']);

/**
 * Normalize legacy/foreign energy values onto the native enum.
 * Legacy web (pre-W3) used low/medium/high; Android sends capitalized
 * Regular/Deep/Shallow. Backend accepts free-form strings (contract).
 */
export function normalizeEnergy(raw: string): TaskEnergy {
	const v = raw.toLowerCase();
	if (VALID_ENERGIES.has(v as TaskEnergy)) return v as TaskEnergy;
	if (v === 'low' || v === 'regular') return 'admin';
	if (v === 'high') return 'deep';
	return 'shallow';
}

/**
 * Web-local due dates are calendar-day keys (YYYY-MM-DD); the wire carries
 * timestamps. Encode as the UTC instant of that key's local noon so the
 * server-side day matches every client's local day.
 */
function dueKeyToWire(dateKey: string): string {
	return new Date(`${dateKey}T12:00:00`).toISOString();
}

export function taskToRemote(task: Task): RemoteTask {
	// Issue #989 PR-C (S6): full-fidelity wire. Counters and trackingMode are
	// mirrored from the local (server-synced) copy so a web push preserves
	// what the phones accumulate — before this change every web push reset
	// them server-side (full-row save of a payload that omitted them).
	// subTasks only travel when web actually holds some: an empty list must
	// stay undefined so the backend's non-nil-slice rule never wipes the
	// phone's subtasks.
	const subtasks = task.subtasks ?? [];
	return {
		syncId: task.id,
		title: task.title,
		energyLevel: task.energy,
		isFinished: task.status === 'completed',
		priority: PRIORITY_TO_INT[task.priority] ?? 0,
		estimatedPomodoros: task.estimatedPomodoros,
		isDeleted: task.status === 'archived',
		trackingMode: task.trackingMode ?? '',
		recurrenceRule: task.recurrenceRule ?? null,
		updatedAt: task.updatedAt,
		createdDate: task.createdAt,
		category: task.list,
		dueDate: task.dueDate ? dueKeyToWire(task.dueDate) : null,
		// Issue #991 S9: the plan travels on the wire (noon encoding, same
		// convention as dueDate).
		plannedDate: task.plannedDate ? dueKeyToWire(task.plannedDate) : null,
		completedAt: task.completedAt ?? null,
		scheduledForToday: task.scheduledForToday === true,
		sortOrder: task.order,
		description: task.notes ?? null,
		completedPomodoros: task.completedPomodoros ?? 0,
		focusedSeconds: task.focusedSeconds ?? 0,
		focusedSecondsPomodoro: task.focusedSecondsPomodoro ?? 0,
		focusedSecondsFlowtime: task.focusedSecondsFlowtime ?? 0,
		focusedSecondsTimeblock: task.focusedSecondsTimeblock ?? 0,
		focusedSecondsStopwatch: task.focusedSecondsStopwatch ?? 0,
		completedFlowtimeSessions: task.completedFlowtimeSessions ?? 0,
		completedTimeblockSessions: task.completedTimeblockSessions ?? 0,
		completedStopwatchSeconds: task.completedStopwatchSeconds ?? 0,
		...(subtasks.length > 0
			? {
					subTasks: subtasks.map((s) => ({
						// Known server subtasks carry their id (`srv-<n>`): the
						// sync upsert's association save UPDATES by primary key —
						// a zero id would be re-INSERTed, duplicating the list on
						// every winning web edit. Web-authored subtasks (no srv-
						// prefix) insert once and gain ids on the next pull.
						...(s.id.startsWith('srv-') ? { id: Number(s.id.slice(4)) } : {}),
						title: s.title,
						isFinished: s.isCompleted
					}))
				}
			: {})
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
	return {
		id: rt.syncId,
		title: rt.title ?? '',
		status,
		priority: INT_TO_PRIORITY[rt.priority] ?? 'none',
		energy: normalizeEnergy(rt.energyLevel ?? 'shallow'),
		estimatedPomodoros: rt.estimatedPomodoros ?? 0,
		list: VALID_LISTS.has(category) ? category : 'inbox',
		// Issue #989 PR-C (S6): the wire now carries the canonical drag order —
		// it beats the caller's stable-index fallback (legacy payloads omit it).
		order: rt.sortOrder ?? order,
		recurrenceRule: rt.recurrenceRule ?? null,
		createdAt: rt.createdDate ?? rt.updatedAt,
		updatedAt: rt.updatedAt,
		// Full-fidelity mirror (#989 PR-C): after one pull the web copy holds
		// everything the phones accumulate, so the next push preserves it.
		dueDate: rt.dueDate ? localDateKey(new Date(rt.dueDate)) : null,
		completedAt: rt.completedAt ?? null,
		scheduledForToday: rt.scheduledForToday === true,
		// Issue #991 S9: the wire now carries plannedDate — decode noon-UTC
		// into the local day key (same round trip as dueDate).
		plannedDate: rt.plannedDate ? localDateKey(new Date(rt.plannedDate)) : null,
		notes: rt.description ?? undefined,
		completedPomodoros: rt.completedPomodoros ?? 0,
		focusedSeconds: rt.focusedSeconds ?? 0,
		focusedSecondsPomodoro: rt.focusedSecondsPomodoro ?? 0,
		focusedSecondsFlowtime: rt.focusedSecondsFlowtime ?? 0,
		focusedSecondsTimeblock: rt.focusedSecondsTimeblock ?? 0,
		focusedSecondsStopwatch: rt.focusedSecondsStopwatch ?? 0,
		completedFlowtimeSessions: rt.completedFlowtimeSessions ?? 0,
		completedTimeblockSessions: rt.completedTimeblockSessions ?? 0,
		completedStopwatchSeconds: rt.completedStopwatchSeconds ?? 0,
		trackingMode: rt.trackingMode ?? undefined,
		subtasks: (rt.subTasks ?? []).map((st, i) => ({
			id: st.id != null ? `srv-${st.id}` : `${rt.syncId}-sub-${i}`,
			title: st.title ?? '',
			isCompleted: st.isFinished,
			sortOrder: i,
			createdAt: rt.updatedAt
		}))
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
