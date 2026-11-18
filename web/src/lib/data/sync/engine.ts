import type { FocusSession, Preferences, Task } from '$lib/domain/entities/types';
import type { ApiClient } from '$lib/data/remote/apiClient';
import type {
	FullSyncResponse,
	InitialUploadResponse,
	RemoteFocusSession,
	RemoteTask,
	UserPreference
} from '$lib/data/remote/types';
import { prefsToRemoteSettings, sessionToRemote, taskToRemote } from './mappers';

export type SyncSnapshot = {
	deviceId: string;
	tasks: Task[];
	sessions: FocusSession[];
	prefs: Preferences;
};

export async function runInitialUpload(
	api: ApiClient,
	snapshot: SyncSnapshot
): Promise<InitialUploadResponse> {
	const sessions = snapshot.sessions
		.map(sessionToRemote)
		.filter((s): s is NonNullable<typeof s> => s != null);

	return api.initialUpload({
		deviceId: snapshot.deviceId,
		tasks: snapshot.tasks.map(taskToRemote),
		sessions,
		settings: prefsToRemoteSettings(snapshot.prefs)
	});
}

export type FullPullResult = {
	tasks: RemoteTask[];
	sessions: RemoteFocusSession[];
	settings: UserPreference[];
	serverTimestamp: string;
};

/**
 * Pull the entire server state for the user by following cursor pagination on
 * both the task and session collections until neither has more. Read-only: no
 * local mutation. Used for the first-pull-after-login and refresh-on-focus.
 */
export async function runFullPull(
	api: ApiClient,
	pageLimit = 100,
	maxPages = 50
): Promise<FullPullResult> {
	let taskCursor: string | undefined;
	let sessionCursor: string | undefined;
	const tasks: RemoteTask[] = [];
	const sessions: RemoteFocusSession[] = [];
	let settings: UserPreference[] = [];
	let serverTimestamp = new Date().toISOString();

	for (let i = 0; i < maxPages; i++) {
		const page: FullSyncResponse = await api.fullSync({ taskCursor, sessionCursor, limit: pageLimit });
		tasks.push(...page.tasks.items);
		sessions.push(...page.sessions.items);
		settings = page.settings; // settings are returned whole on every page
		serverTimestamp = page.serverTimestamp;
		taskCursor = page.tasks.hasMore ? page.tasks.nextCursor : undefined;
		sessionCursor = page.sessions.hasMore ? page.sessions.nextCursor : undefined;
		if (!taskCursor && !sessionCursor) break;
	}

	return { tasks, sessions, settings, serverTimestamp };
}
