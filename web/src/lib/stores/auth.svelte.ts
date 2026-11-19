/**
 * AuthStore — server session, tier, cloud sync (LWW via recovered engine)
 * and WebSocket live updates. Mirrors the native sync loop: pull → merge →
 * persist → push snapshot; server wins ties (recovered merge.ts).
 */
import { browser } from '$app/environment';
import { ApiClient, ApiError, isApiConfigured, type TokenProvider } from '$lib/data/remote/apiClient';
import { clearAuthMeta, getDeviceId, getSyncMeta, listAllTasks, listSessions, loadAuthMeta, saveAuthMeta, saveAllTasks, saveAllSessions, savePreferences, saveSyncMeta } from '$lib/data/local/idb';
import { mergePrefs, mergeSessions, mergeTasks } from '$lib/data/sync/merge';
import { runFullPull, runInitialUpload } from '$lib/data/sync/engine';
import { getPreferences } from '$lib/data/local/idb';
import type { AuthResponse, AuthUser, AuthTokens } from '$lib/data/remote/types';
import type { EntitlementTier } from '$lib/domain/gates/freeLimits';
import { app } from '$lib/stores/app.svelte';
import { plan } from '$lib/stores/plan.svelte';
import { dashboard } from '$lib/stores/dashboard.svelte';

type AuthStatus = 'idle' | 'loading' | 'error';
type MergeChoice = 'pull' | 'upload' | null;

function wsUrl(): string {
	return (__PUBLIC_WS_URL__ || '').replace(/\/$/, '');
}

/** Server tier string → local gate tier (any paid tier unlocks local premium). */
function toGateTier(serverTier: string): EntitlementTier {
	return serverTier && serverTier !== 'free' ? 'everywhere' : 'free';
}

class AuthStore {
	user = $state<AuthUser | null>(null);
	status = $state<AuthStatus>('idle');
	errorCode = $state<string | null>(null);
	syncing = $state(false);
	lastSyncAt = $state<string | null>(null);
	lastSyncError = $state<string | null>(null);
	wsConnected = $state(false);
	mergeChoice = $state<MergeChoice>(null);
	mergeOpen = $state(false);

	api: ApiClient | null = null;
	private ws: WebSocket | null = null;
	private wsRetry = 0;
	private pullThrottle: number | null = null;

	get configured(): boolean {
		return isApiConfigured();
	}

	private provider: TokenProvider = {
		getAccessToken: () => this.tokensSnapshot?.accessToken ?? null,
		getRefreshToken: () => this.tokensSnapshot?.refreshToken ?? null,
		setTokens: async (tokens) => {
			this.tokensSnapshot = tokens;
			await saveAuthMeta({ refreshToken: tokens?.refreshToken ?? null, userJson: tokens ? JSON.stringify(this.user) : null });
		},
		getDeviceId: () => this.deviceIdValue ?? 'unknown'
	};

	private tokensSnapshot: AuthTokens | null = null;
	private deviceIdValue: string | null = null;

	async init(): Promise<void> {
		if (!browser || this.api) return;
		if (!isApiConfigured()) return;
		this.deviceIdValue = await getDeviceId();
		this.api = new ApiClient(this.provider);

		const meta = await loadAuthMeta();
		if (meta.refreshToken) {
			this.status = 'loading';
			try {
				await this.restoreSession();
			} catch {
				this.user = null;
			}
			this.status = 'idle';
		}
		const syncMeta = await getSyncMeta();
		this.lastSyncAt = syncMeta.lastSyncAt;
	}

	private async restoreSession(): Promise<void> {
		const api = this.api!;
		// Refresh to a fresh access token, then fetch the profile.
		const meta = await loadAuthMeta();
		try {
			const { tokens } = await api.refresh(meta.refreshToken!);
			this.tokensSnapshot = tokens;
			await saveAuthMeta({ refreshToken: tokens.refreshToken, userJson: null });
		} catch {
			await this.clearSession();
			return;
		}
		const user = await api.me();
		this.applyUser(user);
		this.connectWs();
		this.watchConnection();
		void this.syncNow(true);
	}

	private applyUser(user: AuthUser): void {
		this.user = user;
		app.setTier(toGateTier(user.subscriptionTier));
	}

	// ---------- Auth flows ----------

	async signIn(email: string, password: string): Promise<boolean> {
		const api = this.api;
		if (!api) return false;
		this.status = 'loading';
		this.errorCode = null;
		try {
			const res: AuthResponse = await api.login(email, password);
			this.tokensSnapshot = res.tokens;
			await saveAuthMeta({ refreshToken: res.tokens.refreshToken, userJson: null });
			this.applyUser(res.user);
			this.status = 'idle';
			await this.decideMergeAndSync();
			this.connectWs();
			return true;
		} catch (e) {
			this.status = 'error';
			this.errorCode = e instanceof ApiError ? e.code : 'unknown_error';
			return false;
		}
	}

	async signUp(email: string, name: string, password: string): Promise<boolean> {
		const api = this.api;
		if (!api) return false;
		this.status = 'loading';
		this.errorCode = null;
		try {
			const res = await api.register(email, name, password);
			this.tokensSnapshot = res.tokens;
			await saveAuthMeta({ refreshToken: res.tokens.refreshToken, userJson: null });
			this.applyUser(res.user);
			this.status = 'idle';
			// New account: push the local snapshot as the seed.
			void this.syncNow(true);
			this.connectWs();
			return true;
		} catch (e) {
			this.status = 'error';
			this.errorCode = e instanceof ApiError ? e.code : 'unknown_error';
			return false;
		}
	}

	async signOut(): Promise<void> {
		const api = this.api;
		if (api) {
			try {
				await api.logout(this.tokensSnapshot?.refreshToken ?? null);
			} catch {
				/* best-effort */
			}
		}
		this.disconnectWs();
		await this.clearSession();
	}

	/** Permanently deletes the cloud account, then clears the local session. */
	async deleteAccount(): Promise<boolean> {
		const api = this.api;
		if (!api) return false;
		try {
			await api.deleteAccount();
		} catch {
			return false;
		}
		this.disconnectWs();
		await this.clearSession();
		return true;
	}

	private async clearSession(): Promise<void> {
		await clearAuthMeta();
		this.tokensSnapshot = null;
		this.user = null;
		app.setTier('free');
		this.lastSyncAt = null;
	}

	async forgotPassword(email: string): Promise<boolean> {
		if (!this.api) return false;
		try {
			await this.api.forgotPassword(email);
			return true;
		} catch {
			return false;
		}
	}

	async resetPassword(token: string, newPassword: string): Promise<boolean> {
		if (!this.api) return false;
		try {
			await this.api.resetPassword(token, newPassword);
			return true;
		} catch {
			return false;
		}
	}

	async refreshEntitlement(): Promise<void> {
		if (!this.api || !this.user) return;
		const user = await this.api.me();
		this.applyUser(user);
	}

	// ---------- Merge decision ----------

	private async decideMergeAndSync(): Promise<void> {
		const api = this.api!;
		let serverHasData = false;
		try {
			serverHasData = await api.hasData();
		} catch {
			/* default to push */
		}
		if (serverHasData) {
			this.mergeOpen = true;
			this.mergeChoice = null;
		} else {
			await this.syncNow(true);
		}
	}

	/** User picked: adopt server data (pull) or overwrite server with local (upload). */
	async resolveMerge(choice: Exclude<MergeChoice, null>): Promise<void> {
		this.mergeChoice = choice;
		this.mergeOpen = false;
		if (choice === 'pull') {
			await this.pullAndApply();
		} else {
			await this.syncNow(true);
		}
	}

	// ---------- Sync loop ----------

	private pushTimer: ReturnType<typeof setTimeout> | null = null;

	/** Debounced push after local mutations (S3 #942): coalesces bursts of
	 * task edits into one upload ~3 s later. Server resolves LWW, so a
	 * redundant push is safe. No-op when signed out. */
	schedulePush(): void {
		if (!this.user) return;
		if (this.pushTimer) clearTimeout(this.pushTimer);
		this.pushTimer = setTimeout(() => {
			this.pushTimer = null;
			void this.syncNow(true);
		}, 3000);
	}

	/** Mutations must never be lost to a tab close inside the debounce. */
	private flushPush(): void {
		if (this.pushTimer) {
			clearTimeout(this.pushTimer);
			this.pushTimer = null;
			void this.syncNow(true);
		}
	}

	watchConnection(): void {
		window.addEventListener('online', () => this.flushPush());
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'hidden') this.flushPush();
		});
		// Stores dispatch this on local writes — avoids importing this store
		// from plan/focus (circular with pullAndApply's plan.init()).
		window.addEventListener('pepinillo:local-mutation', () => this.schedulePush());
	}

	async syncNow(initial = false): Promise<void> {
		const api = this.api;
		if (!api || !this.user || this.syncing) return;
		this.syncing = true;
		this.lastSyncError = null;
		try {
			// 1. Push the local snapshot (server resolves LWW).
			const [prefs, tasks, sessions, deviceId] = await Promise.all([
				getPreferences(),
				listAllTasks(),
				listSessions(),
				getDeviceId()
			]);
			const response = await runInitialUpload(api, { deviceId, tasks, sessions, prefs });
			void response;
			// 2. Pull authoritative server state and merge.
			if (!initial) await this.pullAndApply();
			const meta = await getSyncMeta();
			this.lastSyncAt = new Date().toISOString();
			await saveSyncMeta({ lastSyncAt: this.lastSyncAt, lastPullAt: Date.now() });
			void meta;
		} catch (e) {
			this.lastSyncError = e instanceof ApiError ? e.code : 'sync_error';
		} finally {
			this.syncing = false;
		}
	}

	private async pullAndApply(): Promise<void> {
		const api = this.api!;
		const pull = await runFullPull(api);
		const [localTasks, localSessions] = await Promise.all([listAllTasks(), listSessions()]);
		const remoteTasks = pull.tasks.map((rt, i) => remoteTaskMapper(rt, i));
		const mergedTasks = mergeTasks(localTasks, remoteTasks);
		const remoteSessions = pull.sessions.map(remoteSessionMapper);
		const mergedSessions = mergeSessions(localSessions, remoteSessions);
		await saveAllTasks(mergedTasks);
		await saveAllSessions(mergedSessions);
		const localPrefs = await getPreferences();
		const mergedPrefs = mergePrefs(localPrefs, remoteSettingsToPrefsPartial(pull.settings));
		await savePreferences(mergedPrefs);
		app.updatePrefs(mergedPrefs);
		// Refresh reactive stores from IDB.
		await plan.init();
		await dashboard.reload();
		focusRefreshStats();
	}

	// ---------- WebSocket ----------

	connectWs(): void {
		if (!browser || !this.user) return;
		const base = wsUrl();
		if (!base) return;
		const token = this.tokensSnapshot?.accessToken;
		if (!token) return;
		this.disconnectWs();
		try {
			// Browsers cannot set Authorization headers on WS; the server accepts
			// the bearer token via the Sec-WebSocket-Protocol trick.
			const ws = new WebSocket(`${base}/api/v1/ws?deviceId=${encodeURIComponent(this.provider.getDeviceId())}`, [
				'bearer',
				token
			]);
			ws.onopen = () => {
				this.wsConnected = true;
				this.wsRetry = 0;
			};
			ws.onmessage = (ev) => {
				try {
					const msg = JSON.parse(ev.data as string) as { type?: string };
					if (msg.type && msg.type !== 'pong') this.schedulePull();
				} catch {
					/* ignore malformed frames */
				}
			};
			ws.onclose = () => {
				this.wsConnected = false;
				this.scheduleReconnect();
			};
			ws.onerror = () => ws.close();
			this.ws = ws;
		} catch {
			/* WS is progressive enhancement */
		}
	}

	private disconnectWs(): void {
		this.ws?.close();
		this.ws = null;
		this.wsConnected = false;
	}

	private scheduleReconnect(): void {
		if (!this.user) return;
		const delay = Math.min(30_000, 1000 * 2 ** this.wsRetry++);
		setTimeout(() => this.connectWs(), delay);
	}

	/** Server pushes throttle to one pull per 5 s. */
	private schedulePull(): void {
		if (this.pullThrottle !== null) return;
		this.pullThrottle = window.setTimeout(() => {
			this.pullThrottle = null;
			if (this.user && !this.syncing) void this.pullAndApply();
		}, 5000);
	}
}

/* Lazy mappers to avoid an import cycle at module init. */
import { remoteToTask, remoteToSession, remoteSettingsToPrefs } from '$lib/data/sync/mappers';
function remoteTaskMapper(rt: Parameters<typeof remoteToTask>[0], order: number) {
	return remoteToTask(rt, order);
}
function remoteSessionMapper(rs: Parameters<typeof remoteToSession>[0]) {
	return remoteToSession(rs);
}
function remoteSettingsToPrefsPartial(settings: Parameters<typeof remoteSettingsToPrefs>[0]) {
	return remoteSettingsToPrefs(settings);
}

/* Reactive stores refresh after a pull. */
import { focus } from '$lib/stores/focus.svelte';
function focusRefreshStats(): void {
	void listSessions().then((sessions) => {
		// Trigger stats refresh through the same path the focus controller uses.
		void sessions;
		void focus.init();
	});
}

export const auth = new AuthStore();
