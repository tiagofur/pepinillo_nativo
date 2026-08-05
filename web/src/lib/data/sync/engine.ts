import type { FocusSession, Preferences, Task } from '$lib/domain/entities/types';
import type { ApiClient } from '$lib/data/remote/apiClient';
import type { InitialUploadResponse } from '$lib/data/remote/types';
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
