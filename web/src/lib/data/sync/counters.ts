import type { FocusMode, FocusSession, Task } from '$lib/domain/entities/types';

/**
 * #998 S5: compute the focus counters a web push sends from the completed
 * sessions web actually knows about (its own + phone sessions that arrived
 * via pull), the same way the phones do (iOS SyncClient upload, Android
 * SyncEngine.toDto(sessions)). Before this, a web push mirrored whatever
 * counters the last pull brought, so an LWW-winning web edit could publish
 * a stale snapshot taken before the phone's latest increments.
 *
 * Web task ids ARE the sync ids (remoteToTask maps id: rt.syncId and
 * taskToRemote sends syncId: task.id), so session.taskId always matches
 * the local Task.id — local and pulled sessions share one key space.
 *
 * A task with NO completed known session keeps its mirrored counters: web
 * must never lower a phone's numbers for a task it has not seen sessions
 * of (the pull may not have delivered them yet — the window noted in the
 * issue, strictly better than the old mirror-only behavior).
 */
export function computeFocusCounters(tasks: Task[], sessions: FocusSession[]): Task[] {
	const perTask = new Map<string, FocusSession[]>();
	for (const s of sessions) {
		if (s.status !== 'completed' || !s.taskId) continue;
		const list = perTask.get(s.taskId);
		if (list) list.push(s);
		else perTask.set(s.taskId, [s]);
	}

	const secondsIn = (list: FocusSession[], mode: FocusMode): number =>
		list
			.filter((s) => s.mode === mode)
			.reduce((acc, s) => acc + Math.round(s.elapsedMs / 1000), 0);

	return tasks.map((task) => {
		const list = perTask.get(task.id);
		if (!list || list.length === 0) return task;
		const pomodoro = secondsIn(list, 'pomodoro');
		const flowtime = secondsIn(list, 'flowtime');
		const timeblock = secondsIn(list, 'timeblock');
		const stopwatch = secondsIn(list, 'stopwatch');
		const latest = list.reduce((a, b) => ((a.completedAt ?? '') >= (b.completedAt ?? '') ? a : b));
		return {
			...task,
			focusedSeconds: pomodoro + flowtime + timeblock + stopwatch,
			focusedSecondsPomodoro: pomodoro,
			focusedSecondsFlowtime: flowtime,
			focusedSecondsTimeblock: timeblock,
			focusedSecondsStopwatch: stopwatch,
			completedFlowtimeSessions: list.filter((s) => s.mode === 'flowtime').length,
			completedTimeblockSessions: list.filter((s) => s.mode === 'timeblock').length,
			completedStopwatchSeconds: stopwatch,
			trackingMode: latest.mode
		};
	});
}
