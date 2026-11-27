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
import { toGateTier } from '$lib/domain/gates/entitlements';
import { app } from '$lib/stores/app.svelte';
import { plan } from '$lib/stores/plan.svelte';
import { dashboard } from '$lib/stores/dashboard.svelte';

type AuthStatus = 'idle' | 'loading' | 'error';
type MergeChoice = 'pull' | 'upload' | null;

function wsUrl(): string {
	return (__PUBLIC_WS_URL__ || '').replace(/\/$/, '');
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
			this.watchConnection();
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
			this.watchConnection();
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
		// #998 S4: a pending pull throttle must not survive the session
		// (the re-arm would loop a no-op every 5 s after sign-out).
		if (this.pullThrottle !== null) {
			clearTimeout(this.pullThrottle);
			this.pullThrottle = null;
		}
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

	/** Cambia la contraseña con sesión iniciada (#946 S1). El backend
	 * mantiene la sesión (204). */
	async changePassword(currentPassword: string, newPassword: string): Promise<'ok' | 'wrong' | 'weak' | 'error'> {
		const api = this.api;
		if (!api || !this.user) return 'error';
		try {
			await api.changePassword(currentPassword, newPassword);
			return 'ok';
		} catch (e) {
			if (e instanceof ApiError && e.status === 401) return 'wrong';
			if (e instanceof ApiError && e.code === 'weak_password') return 'weak';
			return 'error';
		}
	}

	/** OAuth por ID token del browser SDK (GIS / Apple ID JS) — mismo
	 * pipeline post-login que signIn (#946 S3). */
	async signInWithProvider(
		provider: 'google' | 'apple',
		idToken: string,
		nonce?: string
	): Promise<boolean> {
		const api = this.api;
		if (!api) return false;
		// Re-entry guard (#946 review P2-3): overlapping provider sign-ins
		// would interleave tokensSnapshot writes.
		if (this.status === 'loading') return false;
		this.status = 'loading';
		this.errorCode = null;
		try {
			const res: AuthResponse =
				provider === 'google'
					? await api.loginWithGoogle(idToken)
					: await api.loginWithApple(idToken, nonce ?? '');
			this.tokensSnapshot = res.tokens;
			await saveAuthMeta({ refreshToken: res.tokens.refreshToken, userJson: null });
			this.applyUser(res.user);
			this.status = 'idle';
			await this.decideMergeAndSync();
			this.watchConnection();
			this.connectWs();
			return true;
		} catch (e) {
			this.status = 'error';
			// Provider endpoints surface their own message (auth.oauth.error).
			this.errorCode = 'oauth_provider_error';
			return false;
		}
	}

	/** Cooldown local del botón Reenviar (60 s) — el server además limita. */
	resendCooldown = $state(0);
	private resendTimer: ReturnType<typeof setInterval> | null = null;

	/** Reenvía el código de verificación al email en sesión (#944 S1). */
	async resendVerification(): Promise<boolean> {
		const api = this.api;
		if (!api || !this.user) return false;
		try {
			await api.resendVerification(this.user.email);
			this.resendCooldown = 60;
			if (this.resendTimer) clearInterval(this.resendTimer);
			this.resendTimer = setInterval(() => {
				this.resendCooldown -= 1;
				if (this.resendCooldown <= 0) {
					if (this.resendTimer) clearInterval(this.resendTimer);
					this.resendTimer = null;
				}
			}, 1000);
			return true;
		} catch {
			return false;
		}
	}

	/** Ingresa el código recibido por email (#944 S2). El backend rota los
	 * tokens en la respuesta — se adoptan junto al user verificado. */
	async verifyEmail(code: string): Promise<'ok' | 'invalid' | 'verified' | 'error'> {
		const api = this.api;
		if (!api || !this.user) return 'error';
		try {
			const res: AuthResponse = await api.verifyEmail(this.user.email, code);
			this.tokensSnapshot = res.tokens;
			await saveAuthMeta({ refreshToken: res.tokens.refreshToken, userJson: null });
			this.applyUser(res.user);
			// The verified gate just opened: clear the stale pre-verification
			// error and push whatever piled up while locked (#944 S4).
			this.lastSyncError = null;
			this.schedulePush();
			return 'ok';
		} catch (e) {
			if (e instanceof ApiError && e.code === 'email_already_verified') return 'verified';
			if (e instanceof ApiError && e.code === 'verification_code_invalid') return 'invalid';
			return 'error';
		}
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
	private pushPending = false;
	private watching = false;

	/** Debounced push after local mutations (S3 #942): coalesces bursts of
	 * task edits into one upload ~3 s later. Server resolves LWW, so a
	 * redundant push is safe. No-op when signed out. */
	schedulePush(): void {
		if (!this.user) return;
		this.pushPending = true;
		if (this.pushTimer) return;
		this.pushTimer = setTimeout(() => this.runPush(), 3000);
	}

	private runPush(): void {
		this.pushTimer = null;
		if (this.syncing) {
			// A sync is in flight (e.g. the initial restore push) — the
			// timer was consumed without effect, so re-arm shortly (#942
			// review P2-7) instead of dropping the mutation.
			this.pushTimer = setTimeout(() => this.runPush(), 1500);
			return;
		}
		this.pushPending = false;
		void this.syncNow(true).then(() => {
			// Failed push (offline, device-bound...) stays pending so the
			// online/visible listeners retry it (#942 review P2-1).
			if (this.lastSyncError) this.pushPending = true;
		});
	}

	/** Mutations must never be lost to a tab close inside the debounce. */
	private flushPush(): void {
		if (this.pushTimer) {
			clearTimeout(this.pushTimer);
			this.runPush();
		} else if (this.pushPending && !this.syncing) {
			this.runPush();
		}
	}

	/** Registers window/document listeners once per session (restore, sign-in
	 * and sign-up all call it — P1-4, #942 review). */
	watchConnection(): void {
		if (this.watching) return;
		this.watching = true;
		window.addEventListener('online', () => this.flushPush());
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'hidden') this.flushPush();
			else if (this.pushPending) this.flushPush();
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
			if (!initial) await this.runPull();
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
		// #998 S4: the standalone pull owns the busy flag and refuses a
		// second concurrent entry (double resolveMerge click). syncNow does
		// NOT go through here — it already holds the flag and drives
		// runPull directly.
		if (this.syncing) return;
		this.syncing = true;
		try {
			await this.runPull();
		} catch (e) {
			this.lastSyncError = e instanceof ApiError ? e.code : 'sync_error';
			throw e;
		} finally {
			this.syncing = false;
		}
	}

	private async runPull(): Promise<void> {
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
			// #998 S4: a pull landing while a sync holds the flag is deferred,
			// not silently dropped (the next WS push re-triggers anyway, but
			// an in-flight push cycle alone would otherwise lose it).
			if (this.user && !this.syncing) void this.pullAndApply();
			else this.schedulePull();
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
