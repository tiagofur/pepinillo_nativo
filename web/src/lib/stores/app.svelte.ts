/**
 * AppStore — single reactive root for the web client (W1 scope).
 *
 * Owns: preferences (locale/appearance/theme), the focus session machine
 * (recovered wall-clock engine), the 250ms ticker, document.title and
 * IndexedDB persistence. Auth/sync/tier wiring lands in W5; the full
 * focus experience (phases, breaks, celebrations, audio) in W2.
 */
import { browser } from '$app/environment';
import {
	completeSession,
	createIdleSession,
	liveElapsedMs,
	pauseSession,
	remainingMs,
	resumeSession,
	recomputeOnVisible,
	skipSession,
	startSession,
	tickSession
} from '$lib/domain/focus/engine';
import {
	DEFAULT_PREFERENCES,
	type FocusMode,
	type FocusSession,
	type Preferences,
	type ThemePreference
} from '$lib/domain/entities/types';
import type { EntitlementTier } from '$lib/domain/gates/freeLimits';
import {
	getDeviceId,
	getPreferences,
	openDb,
	savePreferences,
	saveSession
} from '$lib/data/local/idb';
import { setLocale } from '$lib/i18n/i18n.svelte';
import { formatMs } from '$lib/format/time';

export type ThemeName = 'classic' | 'forest' | 'ocean' | 'sunset';
export const PREMIUM_THEMES: readonly ThemeName[] = ['forest', 'ocean', 'sunset'];

const APPEARANCE_KEY = 'pepinillo.appearance';
const THEME_KEY = 'pepinillo.theme';

class AppStore {
	ready = $state(false);
	prefs = $state<Preferences>({ ...DEFAULT_PREFERENCES, locale: 'es' });
	theme = $state<ThemeName>('classic');
	tier = $state<EntitlementTier>('free');
	deviceId = $state<string | null>(null);

	session = $state<FocusSession | null>(null);
	selectedMode = $state<FocusMode>('pomodoro');
	/** Live display string, recomputed by the ticker (MM:SS / H:MM:SS). */
	displayTime = $state('25:00');

	private ticker: ReturnType<typeof setInterval> | null = null;
	private titleBase = 'Pepinillo';

	async init(): Promise<void> {
		if (!browser || this.ready) return;
		await openDb();
		const [stored, deviceId] = await Promise.all([getPreferences(), getDeviceId()]);
		this.prefs = stored;
		this.deviceId = deviceId;
		this.restoreThemeName();
		this.applyAppearance(stored.theme);
		setLocale(stored.locale);
		await this.restoreSession();
		this.ready = true;
		this.startTicker();
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'visible') this.onTick(true);
		});
	}

	// ---- Preferences ----

	setLocaleOf(locale: Preferences['locale']): void {
		this.prefs = { ...this.prefs, locale };
		setLocale(locale);
		void savePreferences(this.prefs);
	}

	setAppearance(appearance: ThemePreference): void {
		this.prefs = { ...this.prefs, theme: appearance };
		this.applyAppearance(appearance);
		void savePreferences(this.prefs);
	}

	setTheme(theme: ThemeName): void {
		if (theme !== 'classic' && !this.canUseTheme(theme)) return;
		this.theme = theme;
		if (browser) {
			document.documentElement.setAttribute('data-theme', theme);
			try {
				localStorage.setItem(THEME_KEY, theme);
			} catch {
				/* ignore */
			}
		}
	}

	canUseTheme(theme: ThemeName): boolean {
		if (theme === 'classic') return true;
		// Premium themes unlock with Pepinillo+ (tier wiring lands in W5).
		return this.tier !== 'free';
	}

	// ---- Focus session ----

	selectMode(mode: FocusMode): void {
		if (this.session && this.session.status !== 'idle') return;
		this.selectedMode = mode;
		this.session = createIdleSession(mode, {
			workMinutes: this.prefs.pomodoroWorkMinutes
		});
		this.refreshDisplay();
	}

	start(): void {
		if (!this.session) {
			this.session = createIdleSession(this.selectedMode, {
				workMinutes: this.prefs.pomodoroWorkMinutes
			});
		}
		this.session = startSession(this.session, new Date());
		this.persist();
		this.refreshDisplay();
	}

	pause(): void {
		if (!this.session) return;
		this.session = pauseSession(this.session, new Date());
		this.persist();
		this.refreshDisplay();
	}

	resume(): void {
		if (!this.session) return;
		this.session = resumeSession(this.session, new Date());
		this.persist();
		this.refreshDisplay();
	}

	skip(): void {
		if (!this.session) return;
		this.session = skipSession(this.session, new Date());
		this.persist();
		this.resetToIdle();
	}

	complete(): void {
		if (!this.session) return;
		this.session = completeSession(this.session, new Date());
		this.persist();
		this.resetToIdle();
	}

	/** Wall-clock honest: one tick recomputes from the segment anchor. */
	private onTick(fromVisible = false): void {
		if (!this.session) return;
		this.session = fromVisible
			? recomputeOnVisible(this.session, new Date())
			: tickSession(this.session, new Date());
		if (this.session.status === 'completed') {
			this.persist();
			this.resetToIdle();
			return;
		}
		this.refreshDisplay();
	}

	private resetToIdle(): void {
		const mode = this.session?.mode ?? this.selectedMode;
		this.session = createIdleSession(mode, {
			workMinutes: this.prefs.pomodoroWorkMinutes
		});
		this.refreshDisplay();
	}

	private refreshDisplay(): void {
		if (!this.session) {
			this.displayTime = formatMs(0);
			this.updateTitle(null);
			return;
		}
		if (this.session.status === 'idle') {
			this.displayTime = formatMs(this.session.targetMs ?? 0);
		} else {
			const remaining =
				this.session.targetMs != null
					? (remainingMs(this.session, new Date()) ?? 0)
					: liveElapsedMs(this.session, new Date());
			this.displayTime = formatMs(remaining);
		}
		this.updateTitle(this.session);
	}

	private updateTitle(session: FocusSession | null): void {
		if (!browser) return;
		const active = session && (session.status === 'running' || session.status === 'paused');
		document.title = active ? `${this.displayTime} · ${this.titleBase}` : this.titleBase;
	}

	private startTicker(): void {
		this.stopTicker();
		this.ticker = setInterval(() => this.onTick(), 250);
	}

	private stopTicker(): void {
		if (this.ticker) clearInterval(this.ticker);
		this.ticker = null;
	}

	private persist(): void {
		if (!this.session) return;
		void saveSession(this.session).catch(() => {
			/* offline-first: IDB write failures surface in W5 sync diagnostics */
		});
	}

	private async restoreSession(): Promise<void> {
		// W1: restore last idle defaults; full ghost-session resume ships in W2.
		this.session = createIdleSession(this.selectedMode, {
			workMinutes: this.prefs.pomodoroWorkMinutes
		});
	}

	private restoreThemeName(): void {
		try {
			const raw = localStorage.getItem(THEME_KEY);
			if (raw === 'classic' || raw === 'forest' || raw === 'ocean' || raw === 'sunset') {
				this.theme = raw;
			}
		} catch {
			/* ignore */
		}
	}

	private applyAppearance(appearance: ThemePreference): void {
		if (!browser) return;
		if (appearance === 'system') {
			document.documentElement.removeAttribute('data-appearance');
			try {
				localStorage.removeItem(APPEARANCE_KEY);
			} catch {
				/* ignore */
			}
		} else {
			document.documentElement.setAttribute('data-appearance', appearance);
			try {
				localStorage.setItem(APPEARANCE_KEY, appearance);
			} catch {
				/* ignore */
			}
		}
	}
}

export const app = new AppStore();
