import { browser } from '$app/environment';
import {
	getDeviceId,
	getPreferences,
	listActiveTasks,
	listAllTasks,
	listSessions,
	savePreferences,
	saveSession,
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
import { canCreateActiveTask, canUseMode } from '$lib/domain/gates/freeLimits';
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

/** Free tier only in W1 — no Everywhere entitlement yet. */
export const TIER = 'free' as const;

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
	#tickHandle: ReturnType<typeof setInterval> | null = null;

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
		this.applyTheme(this.prefs.theme);
		this.focusSession = createIdleSession(this.selectedMode, {
			workMinutes: this.prefs.pomodoroWorkMinutes
		});
		this.ready = true;
		this.#bindVisibility();
		this.#bindSystemTheme();
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
		if (!canUseMode(mode, TIER)) {
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
		if (!canUseMode(this.selectedMode, TIER)) {
			this.upgradeTeaser = 'mode';
			return;
		}
		const now = new Date().toISOString();
		this.focusSession = startSession(this.focusSession, now);
		this.#startTicker();
	}

	pauseFocus() {
		const now = new Date().toISOString();
		this.focusSession = pauseSession(this.focusSession, now);
		this.#stopTicker();
	}

	resumeFocus() {
		const now = new Date().toISOString();
		this.focusSession = resumeSession(this.focusSession, now);
		this.#startTicker();
	}

	async skipFocus() {
		const now = new Date().toISOString();
		this.focusSession = skipSession(this.focusSession, now);
		this.#stopTicker();
		await this.#persistSession(this.focusSession);
	}

	async completeFocus() {
		const now = new Date().toISOString();
		this.focusSession = completeSession(this.focusSession, now);
		this.#stopTicker();
		await this.#persistSession(this.focusSession);
	}

	resetFocus() {
		this.#stopTicker();
		this.focusSession = createIdleSession(this.selectedMode, {
			workMinutes: this.prefs.pomodoroWorkMinutes
		});
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
		if (!canCreateActiveTask(active.length, TIER)) {
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
	}

	async deleteTask(id: string) {
		await removeTask(id);
		this.tasks = await listAllTasks();
	}

	async reorderTasks(orderedIds: string[]) {
		const now = new Date().toISOString();
		for (let i = 0; i < orderedIds.length; i++) {
			const task = this.tasks.find((t) => t.id === orderedIds[i]);
			if (!task) continue;
			await upsertTask({ ...task, order: i, updatedAt: now });
		}
		this.tasks = await listAllTasks();
	}

	async #persistSession(session: FocusSession) {
		if (session.status !== 'completed' && session.status !== 'skipped') return;
		await saveSession(session);
		this.sessions = await listSessions();
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
				void this.#persistSession(next);
			}
		}, 250);
	}

	#stopTicker() {
		if (this.#tickHandle) {
			clearInterval(this.#tickHandle);
			this.#tickHandle = null;
		}
	}

	#bindVisibility() {
		if (!browser) return;
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'visible') {
				const iso = new Date().toISOString();
				this.focusSession = recomputeOnVisible(this.focusSession, iso);
				this.nowMs = Date.now();
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
