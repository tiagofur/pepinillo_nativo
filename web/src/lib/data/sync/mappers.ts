import type { FocusSession, Preferences, Task } from '$lib/domain/entities/types';
import type { RemoteFocusSession, RemoteTask } from '$lib/data/remote/types';

const PRIORITY_TO_INT: Record<Task['priority'], number> = {
	low: 1,
	medium: 2,
	high: 3
};

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

export function prefsToRemoteSettings(prefs: Preferences): { key: string; value: string; updatedAt: string }[] {
	const now = new Date().toISOString();
	return [
		{ key: 'locale', value: prefs.locale, updatedAt: now },
		{ key: 'theme', value: prefs.theme, updatedAt: now },
		{ key: 'autoStartNext', value: String(prefs.autoStartNext), updatedAt: now },
		{ key: 'pomodoroWorkMinutes', value: String(prefs.pomodoroWorkMinutes), updatedAt: now },
		{ key: 'pomodoroBreakMinutes', value: String(prefs.pomodoroBreakMinutes), updatedAt: now }
	];
}
