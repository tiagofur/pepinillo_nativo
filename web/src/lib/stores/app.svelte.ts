import { browser } from '$app/environment';
import {
	clearAuthMeta,
	clearSyncMeta,
	getDeviceId,
	getPreferences,
	getSyncMeta,
	listActiveTasks,
	listAllTasks,
	listSessions,
	loadAuthMeta,
	saveAllSessions,
	saveAllTasks,
	saveAuthMeta,
	savePreferences,
	saveSession,
	saveSyncMeta,
	upsertTask,
	removeTask
} from '$lib/data/local/idb';
import type {
	FocusMode,
	FocusSession,
	LocaleCode,
	Preferences,
	Task,
	TaskEnergy,
	TaskList,
	TaskPriority,
	ThemePreference
} from '$lib/domain/entities/types';
import { DEFAULT_PREFERENCES } from '$lib/domain/entities/types';
import {
	canCreateActiveTask,
	canUseMode,
	type EntitlementTier
} from '$lib/domain/gates/freeLimits';
import { canSync, isEverywhereActive } from '$lib/domain/gates/entitlements';
import {
	completeSession,
	createIdleSession,
	linkTask,
	liveElapsedMs,
	pauseSession,
	recomputeOnVisible,
	resumeSession,
	setJournal,
	skipSession,
	startSession,
	tickSession
} from '$lib/domain/focus/engine';
import { ApiClient, ApiError, isApiConfigured } from '$lib/data/remote/apiClient';
import type { AuthTokens, AuthUser, RemoteFocusSession, RemoteTask, UserPreference } from '$lib/data/remote/types';
import { runFullPull, runInitialUpload } from '$lib/data/sync/engine';
import { remoteToSession, remoteToTask, remoteSettingsToPrefs } from '$lib/data/sync/mappers';
import { mergePrefs, mergeSessions, mergeTasks } from '$lib/data/sync/merge';

/** @deprecated Prefer `app.tier` — static Free for tests that import TIER. */
export const TIER: EntitlementTier = 'free';

class AppState {
	ready = $state(false);
	prefs = $state<Preferences>({ ...DEFAULT_PREFERENCES });
	deviceId = $state('');
	tasks = $state<Task[]>([]);
	sessions = $state<FocusSession[]>([]);
	focusSession = $state<FocusSession>(createIdleSession('pomodoro'));
	selectedMode = $state<FocusMode>('pomodoro');
	nowMs = $state(Date.now());
	upgradeTeaser = $state<string | null>(null);
	/** Ephemeral UI toast (session complete, export, etc.) */
	toast = $state<string | null>(null);
	/** Signed-in remote user (null = Free local only). */
	user = $state<AuthUser | null>(null);
	authBusy = $state(false);
	authError = $state<string | null>(null);
	syncBusy = $state(false);
	lastSyncMessage = $state<string | null>(null);
	/** ISO time of the last successful full round-trip sync, for display. */
	lastSyncAt = $state<string | null>(null);
	/** Server already had data — show merge notice after upload. */
	mergeNotice = $state<string | null>(null);
	accessToken = $state<string | null>(null);
	#refreshToken: string | null = null;
	#api: ApiClient | null = null;
	#tickHandle: ReturnType<typeof setInterval> | null = null;
	#wakeLock: WakeLockSentinel | null = null;
	#toastTimer: ReturnType<typeof setTimeout> | null = null;
	/** Epoch ms of the last cloud pull — throttles refresh-on-refocus. */
	#lastPullAt = 0;
	/** Debounced auto-sync handle (push local mutations up when Everywhere). */
	#pushTimer: ReturnType<typeof setTimeout> | null = null;

	async init() {
		if (!browser) {
			this.ready = true;
			return;
		}
		this.deviceId = await getDeviceId();
		this.prefs = await getPreferences();
		if (!this.prefs.locale) {
			this.prefs = { ...this.prefs, locale: detectBrowserLocale() };
		}
		this.tasks = await listAllTasks();
		this.sessions = await listSessions();
		const syncMeta = await getSyncMeta();
		this.lastSyncAt = syncMeta.lastSyncAt;
		this.#lastPullAt = syncMeta.lastPullAt ?? 0;
		this.applyTheme(this.prefs.theme);
		this.focusSession = createIdleSession(this.selectedMode, {
			workMinutes: this.prefs.pomodoroWorkMinutes
		});
		this.#api = new ApiClient(this.#tokenProvider());
		await this.#restoreSession();
		this.ready = true;
		this.#bindVisibility();
		this.#bindSystemTheme();
	}

	get tier(): EntitlementTier {
		return isEverywhereActive(this.user) ? 'everywhere' : 'free';
	}

	get isSignedIn(): boolean {
		return this.user != null && this.#refreshToken != null;
	}

	get apiConfigured(): boolean {
		return isApiConfigured();
	}

	get canUseEverywhereSync(): boolean {
		return canSync(this.user);
	}

	get locale(): LocaleCode {
		return this.prefs.locale;
	}

	get activeTasks(): Task[] {
		return this.tasks.filter((t) => t.status === 'active');
	}

	get onboardingOpen(): boolean {
		return this.ready && !this.prefs.onboardingCompleted;
	}

	async completeOnboarding() {
		await this.updatePrefs({ onboardingCompleted: true });
	}

	async updatePrefs(partial: Partial<Preferences>) {
		this.prefs = { ...this.prefs, ...partial };
		if (partial.theme) this.applyTheme(partial.theme);
		if (browser) await savePreferences(this.prefs);
		this.#schedulePush();
	}

	applyTheme(theme: ThemePreference) {
		if (!browser) return;
		const root = document.documentElement;
		if (theme === 'system') {
			root.removeAttribute('data-theme');
		} else {
			root.setAttribute('data-theme', theme);
		}
		this.#syncThemeColor();
	}

	/** Browser chrome (mobile status bar) follows Pepinillo surfaces. */
	#syncThemeColor() {
		if (!browser) return;
		const meta = document.querySelector('meta[name="theme-color"]');
		if (!meta) return;
		const dark =
			document.documentElement.getAttribute('data-theme') === 'dark' ||
			(document.documentElement.getAttribute('data-theme') == null &&
				window.matchMedia('(prefers-color-scheme: dark)').matches);
		meta.setAttribute('content', dark ? '#1a1c19' : '#38803b');
	}

	selectMode(mode: FocusMode) {
		if (!canUseMode(mode, this.tier)) {
			this.upgradeTeaser = 'mode';
			return;
		}
		this.upgradeTeaser = null;
		this.selectedMode = mode;
		if (this.focusSession.status === 'idle') {
			this.focusSession = createIdleSession(mode, {
				workMinutes: this.prefs.pomodoroWorkMinutes
			});
		}
	}

	startFocus() {
		if (!canUseMode(this.selectedMode, this.tier)) {
			this.upgradeTeaser = 'mode';
			return;
		}
		const now = new Date().toISOString();
		this.focusSession = startSession(this.focusSession, now);
		this.#startTicker();
		void this.#requestWakeLock();
	}

	pauseFocus() {
		const now = new Date().toISOString();
		this.focusSession = pauseSession(this.focusSession, now);
		this.#stopTicker();
		void this.#releaseWakeLock();
	}

	resumeFocus() {
		const now = new Date().toISOString();
		this.focusSession = resumeSession(this.focusSession, now);
		this.#startTicker();
		void this.#requestWakeLock();
	}

	async skipFocus() {
		const now = new Date().toISOString();
		this.focusSession = skipSession(this.focusSession, now);
		this.#stopTicker();
		void this.#releaseWakeLock();
		await this.#persistSession(this.focusSession);
		this.showToastKey('toast.sessionSkipped');
	}

	async completeFocus() {
		const now = new Date().toISOString();
		this.focusSession = completeSession(this.focusSession, now);
		this.#stopTicker();
		void this.#releaseWakeLock();
		await this.#persistSession(this.focusSession);
		this.showToastKey('toast.sessionComplete');
	}

	resetFocus() {
		this.#stopTicker();
		void this.#releaseWakeLock();
		this.focusSession = createIdleSession(this.selectedMode, {
			workMinutes: this.prefs.pomodoroWorkMinutes
		});
	}

	showToast(message: string) {
		this.toast = message;
		if (this.#toastTimer) clearTimeout(this.#toastTimer);
		this.#toastTimer = setTimeout(() => {
			this.toast = null;
			this.#toastTimer = null;
		}, 3200);
	}

	/** Resolve later in UI via i18n; store raw key for layout. */
	showToastKey(key: string) {
		this.showToast(key);
	}

	dismissToast() {
		this.toast = null;
		if (this.#toastTimer) {
			clearTimeout(this.#toastTimer);
			this.#toastTimer = null;
		}
	}

	async exportLocalData(): Promise<void> {
		if (!browser) return;
		const payload = {
			exportedAt: new Date().toISOString(),
			deviceId: this.deviceId,
			tier: TIER,
			preferences: this.prefs,
			tasks: this.tasks,
			sessions: this.sessions
		};
		const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `pepinillo-web-export-${new Date().toISOString().slice(0, 10)}.json`;
		a.click();
		URL.revokeObjectURL(url);
		this.showToastKey('toast.exportDone');
	}

	setFocusJournal(text: string) {
		this.focusSession = setJournal(this.focusSession, text);
	}

	setFocusTask(taskId: string | null) {
		this.focusSession = linkTask(this.focusSession, taskId);
	}

	get displayElapsedMs(): number {
		return liveElapsedMs(this.focusSession, new Date(this.nowMs).toISOString());
	}

	async createTask(input: {
		title: string;
		priority: TaskPriority;
		energy: TaskEnergy;
		estimatedPomodoros: number;
		list: TaskList;
	}): Promise<{ ok: true } | { ok: false; reason: 'cap' }> {
		const active = await listActiveTasks();
		if (!canCreateActiveTask(active.length, this.tier)) {
			this.upgradeTeaser = 'tasks';
			return { ok: false, reason: 'cap' };
		}
		const now = new Date().toISOString();
		const task: Task = {
			id: crypto.randomUUID(),
			title: input.title.trim(),
			status: 'active',
			priority: input.priority,
			energy: input.energy,
			estimatedPomodoros: input.estimatedPomodoros,
			list: input.list,
			order: active.length,
			createdAt: now,
			updatedAt: now
		};
		await upsertTask(task);
		this.tasks = await listAllTasks();
		this.#schedulePush();
		return { ok: true };
	}

	async completeTask(id: string) {
		const task = this.tasks.find((t) => t.id === id);
		if (!task) return;
		const updated = {
			...task,
			status: 'completed' as const,
			updatedAt: new Date().toISOString()
		};
		await upsertTask(updated);
		this.tasks = await listAllTasks();
		this.#schedulePush();
	}

	async deleteTask(id: string) {
		await removeTask(id);
		this.tasks = await listAllTasks();
		this.#schedulePush();
	}

	async reorderTasks(orderedIds: string[]) {
		const now = new Date().toISOString();
		for (let i = 0; i < orderedIds.length; i++) {
			const task = this.tasks.find((t) => t.id === orderedIds[i]);
			if (!task) continue;
			await upsertTask({ ...task, order: i, updatedAt: now });
		}
		this.tasks = await listAllTasks();
		this.#schedulePush();
	}

	async login(email: string, password: string) {
		if (!this.#api) return;
		this.authBusy = true;
		this.authError = null;
		try {
			const res = await this.#api.login(email.trim(), password);
			await this.#applyAuth(res.user, res.tokens);
			this.showToastKey('toast.signedIn');
		} catch (e) {
			this.authError = e instanceof ApiError ? e.code : 'login_failed';
		} finally {
			this.authBusy = false;
		}
	}

	async register(email: string, name: string, password: string) {
		if (!this.#api) return;
		this.authBusy = true;
		this.authError = null;
		try {
			const res = await this.#api.register(email.trim(), name.trim(), password);
			await this.#applyAuth(res.user, res.tokens);
			this.showToastKey('toast.registered');
		} catch (e) {
			this.authError = e instanceof ApiError ? e.code : 'register_failed';
		} finally {
			this.authBusy = false;
		}
	}

	async logout() {
		if (this.#api && this.accessToken) {
			try {
				await this.#api.logout(this.#refreshToken);
			} catch {
				/* still clear local session */
			}
		}
		if (this.#pushTimer) {
			clearTimeout(this.#pushTimer);
			this.#pushTimer = null;
		}
		this.accessToken = null;
		this.#refreshToken = null;
		this.user = null;
		this.mergeNotice = null;
		this.lastSyncMessage = null;
		this.lastSyncAt = null;
		this.#lastPullAt = 0;
		await clearAuthMeta();
		await clearSyncMeta();
		this.showToastKey('toast.signedOut');
	}

	async refreshProfile() {
		if (!this.#api || !this.isSignedIn) return;
		try {
			this.user = await this.#api.me();
			await this.#persistAuthMeta();
		} catch (e) {
			if (e instanceof ApiError && e.status === 401) {
				await this.logout();
			}
		}
	}

	/**
	 * Full round-trip sync: upload local snapshot (initial-upload is idempotent
	 * and upserts), then apply the merged server state back to IndexedDB. This
	 * is the single primitive that makes the web bidirectional. Requires
	 * Everywhere.
	 */
	async syncNow() {
		if (!this.#api || !this.isSignedIn) {
			this.lastSyncMessage = 'auth.required';
			return;
		}
		if (!this.canUseEverywhereSync) {
			this.lastSyncMessage = 'sync.everywhereRequired';
			this.upgradeTeaser = 'sync';
			return;
		}
		this.syncBusy = true;
		this.lastSyncMessage = null;
		this.mergeNotice = null;
		try {
			const result = await runInitialUpload(this.#api, {
				deviceId: this.deviceId,
				tasks: this.tasks,
				sessions: this.sessions,
				prefs: this.prefs
			});
			const merged = await this.#applyServerSnapshot(result.tasks, result.sessions, result.settings);
			if (result.hasExistingData) {
				this.mergeNotice = 'sync.mergeExisting';
				this.showToastKey('toast.syncMerged');
			} else {
				this.showToastKey('toast.syncOk');
			}
			this.lastSyncAt = merged.updatedAt;
			this.#lastPullAt = Date.now();
			await saveSyncMeta({ lastSyncAt: this.lastSyncAt, lastPullAt: this.#lastPullAt });
			this.lastSyncMessage = 'sync.ok';
		} catch (e) {
			this.lastSyncMessage = e instanceof ApiError ? e.code : 'sync_failed';
		} finally {
			this.syncBusy = false;
		}
	}

	/**
	 * Read-only pull: fetch the full server state and merge it into local. Used
	 * for refresh-on-refocus and manual "refresh from cloud". Does not push.
	 */
	async pullFromCloud(): Promise<boolean> {
		if (!this.#api || !this.isSignedIn || !this.canUseEverywhereSync) return false;
		try {
			const pulled = await runFullPull(this.#api);
			const merged = await this.#applyServerSnapshot(pulled.tasks, pulled.sessions, pulled.settings);
			this.lastSyncAt = pulled.serverTimestamp;
			this.#lastPullAt = Date.now();
			await saveSyncMeta({ lastSyncAt: this.lastSyncAt, lastPullAt: this.#lastPullAt });
			this.showToastKey('toast.syncPullDone');
			return true;
		} catch {
			this.lastSyncMessage = 'sync.pullError';
			return false;
		}
	}

	/**
	 * Reverse-map remote entities to local shape, LWW-merge with the current
	 * arrays, persist the merged superset to IndexedDB, and refresh reactive
	 * state. Returns the resulting `updatedAt` watermark.
	 */
	async #applyServerSnapshot(
		remoteTasks: RemoteTask[],
		remoteSessions: RemoteFocusSession[],
		settings: UserPreference[]
	): Promise<{ updatedAt: string }> {
		const remoteTasksLocal = remoteTasks.map((rt, i) => remoteToTask(rt, i));
		const remoteSessionsLocal = remoteSessions.map(remoteToSession);
		const remotePrefsPartial = remoteSettingsToPrefs(settings);

		const mergedTasks = mergeTasks(this.tasks, remoteTasksLocal);
		const mergedSessions = mergeSessions(this.sessions, remoteSessionsLocal);
		const mergedPrefs = mergePrefs(this.prefs, remotePrefsPartial);

		await saveAllTasks(mergedTasks);
		await saveAllSessions(mergedSessions);
		if (Object.keys(remotePrefsPartial).length > 0) {
			this.prefs = mergedPrefs;
			if (remotePrefsPartial.theme) this.applyTheme(mergedPrefs.theme);
			await savePreferences(mergedPrefs);
		}

		this.tasks = mergedTasks;
		this.sessions = mergedSessions;

		const all = [...mergedTasks.map((t) => t.updatedAt), ...mergedSessions.map((s) => s.updatedAt)];
		const updatedAt = all.length ? all.sort().at(-1)! : new Date().toISOString();
		return { updatedAt };
	}

	/**
	 * Debounced auto-sync: when an Everywhere user mutates local data, push the
	 * change up after a short quiet period so bursts coalesce into one request.
	 * No-op when signed-out or not entitled.
	 */
	#schedulePush(delayMs = 3000) {
		if (!browser || !this.isSignedIn || !this.canUseEverywhereSync) return;
		if (this.#pushTimer) clearTimeout(this.#pushTimer);
		this.#pushTimer = setTimeout(() => {
			this.#pushTimer = null;
			void this.syncNow();
		}, delayMs);
	}

	async #applyAuth(user: AuthUser, tokens: AuthTokens) {
		this.user = user;
		this.accessToken = tokens.accessToken;
		this.#refreshToken = tokens.refreshToken;
		await this.#persistAuthMeta();
		// Prefer server profile (tier) right after auth
		try {
			this.user = await this.#api!.me();
			await this.#persistAuthMeta();
		} catch {
			/* keep login user payload */
		}
		// First sync: upload local Free data and pull the merged cloud state.
		// Fire-and-forget so the UI never blocks on login.
		if (this.canUseEverywhereSync) {
			void this.syncNow();
		}
	}

	async #restoreSession() {
		const meta = await loadAuthMeta();
		this.#refreshToken = meta.refreshToken;
		if (meta.userJson) {
			try {
				this.user = JSON.parse(meta.userJson) as AuthUser;
			} catch {
				this.user = null;
			}
		}
		if (!this.#refreshToken || !this.#api || !isApiConfigured()) return;
		try {
			const { tokens } = await this.#api.refresh(this.#refreshToken);
			this.accessToken = tokens.accessToken;
			this.#refreshToken = tokens.refreshToken;
			this.user = await this.#api.me();
			await this.#persistAuthMeta();
		} catch {
			this.accessToken = null;
			this.#refreshToken = null;
			this.user = null;
			await clearAuthMeta();
		}
	}

	async #persistAuthMeta() {
		await saveAuthMeta({
			refreshToken: this.#refreshToken,
			userJson: this.user ? JSON.stringify(this.user) : null
		});
	}

	#tokenProvider() {
		return {
			getAccessToken: () => this.accessToken,
			getRefreshToken: () => this.#refreshToken,
			setTokens: async (tokens: AuthTokens | null) => {
				if (!tokens) {
					this.accessToken = null;
					this.#refreshToken = null;
					await this.#persistAuthMeta();
					return;
				}
				this.accessToken = tokens.accessToken;
				this.#refreshToken = tokens.refreshToken;
				await this.#persistAuthMeta();
			},
			getDeviceId: () => this.deviceId
		};
	}

	async #persistSession(session: FocusSession) {
		if (session.status !== 'completed' && session.status !== 'skipped') return;
		await saveSession(session);
		this.sessions = await listSessions();
		this.#schedulePush();
	}

	#startTicker() {
		this.#stopTicker();
		this.nowMs = Date.now();
		this.#tickHandle = setInterval(() => {
			this.nowMs = Date.now();
			const iso = new Date(this.nowMs).toISOString();
			// Auto-complete countdown modes when wall-clock hits target.
			if (
				this.focusSession.status === 'running' &&
				this.focusSession.targetMs != null &&
				liveElapsedMs(this.focusSession, iso) >= this.focusSession.targetMs
			) {
				const next = tickSession(this.focusSession, iso);
				this.focusSession = next;
				this.#stopTicker();
				void this.#releaseWakeLock();
				void this.#persistSession(next);
				this.showToastKey('toast.sessionComplete');
			}
		}, 250);
	}

	#stopTicker() {
		if (this.#tickHandle) {
			clearInterval(this.#tickHandle);
			this.#tickHandle = null;
		}
	}

	async #requestWakeLock() {
		if (!browser || !('wakeLock' in navigator)) return;
		try {
			await this.#releaseWakeLock();
			this.#wakeLock = await navigator.wakeLock.request('screen');
			this.#wakeLock.addEventListener('release', () => {
				this.#wakeLock = null;
			});
		} catch {
			// Permission / battery policy — best effort only
			this.#wakeLock = null;
		}
	}

	async #releaseWakeLock() {
		if (!this.#wakeLock) return;
		try {
			await this.#wakeLock.release();
		} catch {
			/* ignore */
		}
		this.#wakeLock = null;
	}

	#bindVisibility() {
		if (!browser) return;
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'visible') {
				const iso = new Date().toISOString();
				this.focusSession = recomputeOnVisible(this.focusSession, iso);
				this.nowMs = Date.now();
				if (this.focusSession.status === 'running') {
					void this.#requestWakeLock();
				}
				// Pull fresh data from the cloud when returning to the tab, but
				// throttle to once per minute so we don't hammer the backend.
				if (this.isSignedIn && this.canUseEverywhereSync && Date.now() - this.#lastPullAt > 60_000) {
					void this.pullFromCloud();
				}
			}
		});
	}

	#bindSystemTheme() {
		if (!browser || !window.matchMedia) return;
		const mq = window.matchMedia('(prefers-color-scheme: dark)');
		const onChange = () => {
			if (this.prefs.theme === 'system') this.#syncThemeColor();
		};
		mq.addEventListener('change', onChange);
	}
}

function detectBrowserLocale(): LocaleCode {
	const raw = (typeof navigator !== 'undefined' ? navigator.language : 'en').toLowerCase();
	if (raw.startsWith('es')) return 'es';
	if (raw.startsWith('pt')) return 'pt';
	return 'en';
}

export const app = new AppState();
