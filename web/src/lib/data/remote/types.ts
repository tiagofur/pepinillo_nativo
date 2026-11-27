export type AuthTokens = {
	accessToken: string;
	refreshToken: string;
	expiresIn: number;
};

export type AuthUser = {
	id: string;
	email: string;
	name: string;
	subscriptionTier: string;
	subscriptionExpiresAt?: string | null;
	emailVerified: boolean;
	imageUrl?: string | null;
};

export type AuthResponse = {
	user: AuthUser;
	tokens: AuthTokens;
};

export type ApiErrorBody = {
	error?: string;
	message?: string;
};

/** Backend task shape (subset for sync). */
export type RemoteTask = {
	id?: number;
	syncId: string;
	userId?: string;
	title?: string | null;
	energyLevel?: string | null;
	isFinished: boolean;
	priority: number;
	estimatedPomodoros: number;
	isDeleted: boolean;
	trackingMode?: string;
	recurrenceRule?: string | null;
	updatedAt: string;
	createdDate?: string | null;
	category?: string | null;
	/* ---- #989 PR-C (S6): canonical task-model fields ---- */
	dueDate?: string | null;
	completedAt?: string | null;
	scheduledForToday?: boolean;
	plannedDate?: boolean;
	sortOrder?: number;
	description?: string | null;
	completedPomodoros?: number;
	focusedSeconds?: number;
	focusedSecondsPomodoro?: number;
	focusedSecondsFlowtime?: number;
	focusedSecondsTimeblock?: number;
	focusedSecondsStopwatch?: number;
	completedFlowtimeSessions?: number;
	completedTimeblockSessions?: number;
	completedStopwatchSeconds?: number;
	subTasks?: RemoteSubTask[];
};

/** Backend subtask shape (nested in RemoteTask.subTasks). */
export type RemoteSubTask = {
	id?: number | null;
	taskId?: number | null;
	title?: string | null;
	isFinished: boolean;
};

/** Backend focus session shape (subset for sync). */
export type RemoteFocusSession = {
	id: string;
	userId?: string;
	taskSyncId?: string | null;
	startedAt: string;
	endedAt?: string | null;
	mode: string;
	phase: string;
	durationSeconds: number;
	elapsedSeconds: number;
	pauseCount: number;
	totalPauseSeconds: number;
	wasCompleted: boolean;
	journalNote?: string;
	createdAt?: string;
	updatedAt: string;
};

/** Backend user preference (key/value row). */
export type UserPreference = {
	userId?: string;
	key: string;
	value: string;
	updatedAt?: string;
};

/** Cursor-paginated page (matches backend `PaginatedPage[T]`). */
export type PaginatedPage<T> = {
	items: T[];
	nextCursor?: string;
	hasMore: boolean;
};

export type InitialUploadRequest = {
	deviceId: string;
	tasks: RemoteTask[];
	sessions: RemoteFocusSession[];
	settings: UserPreference[];
};

export type InitialUploadResponse = {
	tasks: RemoteTask[];
	sessions: RemoteFocusSession[];
	settings: UserPreference[];
	serverTimestamp: string;
	hasExistingData: boolean;
};

/** GET /sync/full response. */
export type FullSyncResponse = {
	tasks: PaginatedPage<RemoteTask>;
	sessions: PaginatedPage<RemoteFocusSession>;
	settings: UserPreference[];
	serverTimestamp: string;
};
