/**
 * FocusController — full native-parity focus flow (W2).
 * Owns: phase machine per mode, wall-clock ticker, records persistence,
 * celebrations, journal prompt, notifications, WakeLock, haptics, audio.
 *
 * Timing stays wall-clock honest (recovered engine): recompute on
 * visibilitychange; a persisted running session offers a ghost resume
 * after a tab close.
 */
import { browser } from '$app/environment';
import {
	completeSession,
	createIdleSession,
	liveElapsedMs,
	pauseSession,
	remainingMs,
	resumeSession,
	skipSession,
	startSession,
	tickSession,
	recomputeOnVisible
} from '$lib/domain/focus/engine';
import {
	advanceAfterBreak,
	advanceAfterCompletedWork,
	adjustBlockMinutes as adjustBlock,
	flowtimeBreakMinutes,
	isBreakPhase,
	midpointReached,
	pomodoroConfigFrom,
	rollPomodoroNumber,
	type PomodoroCycleState
} from '$lib/domain/focus/phases';
import {
	buildDailyStats,
	computeBestStreak,
	computeStreak,
	dateKey,
	type DailyStat
} from '$lib/domain/stats/daily';
import { breakVariant, CLASSIC_MODE_HEX } from '$lib/domain/focus/phaseColors';
import {
	evaluateMilestone,
	FRESH_LATCHES,
	isStreakRecord,
	type Milestone,
	type MilestoneLatches
} from '$lib/domain/celebrations/milestones';
import {
	haptic,
	playCompletionSound,
	primeAudio,
	startSoundscape,
	type SoundscapeHandle
} from '$lib/domain/audio/sounds';
import { formatMs } from '$lib/format/time';
import {
	getMetaValue,
	listAllTasks,
	listSessions,
	saveSession,
	setMetaValue,
	upsertTask
} from '$lib/data/local/idb';
import { app } from '$lib/stores/app.svelte';
import type { FocusMode, FocusPhase, FocusSession, Task } from '$lib/domain/entities/types';

const CYCLE_META_ID = 'focus.cycle';
const LATCHES_META_ID = 'focus.milestones';
const BEST_STREAK_META_ID = 'focus.bestStreak';

interface PersistedCycle extends PomodoroCycleState {
	lastActivityDateKey: string;
}

const JOURNAL_MIN_MS = 60_000;
const GHOST_MAX_AGE_MS = 12 * 3600_000;

/** Mirror of the plan store's hook — fires the auth store's debounced push. */
function notifyMutation(): void {
	if (browser && typeof window !== 'undefined')
		window.dispatchEvent(new Event('pepinillo:local-mutation'));
}

class FocusController {
	mode = $state<FocusMode>('pomodoro');
	session = $state<FocusSession | null>(null);
	displayTime = $state('25:00');
	cycle = $state<PomodoroCycleState>({ pomodoroNumber: 1, completedInCycle: 0 });

	waiting = $state(false);
	breakSuggested = $state(false);
	midpointNotified = $state(false);

	journalPrompt = $state<{ sessionId: string } | null>(null);
	milestone = $state<Milestone | null>(null);
	streakRecord = $state(false);

	todayStat = $state<DailyStat | null>(null);
	streak = $state(0);
	bestStreak = $state(0);
	ghost = $state<FocusSession | null>(null);
	activeTask = $state<Task | null>(null);

	blockMinutes = $state(60);

	private ticker: ReturnType<typeof setInterval> | null = null;
	private pausedAt: string | null = null;
	private soundscape: SoundscapeHandle | null = null;
	private wakeLock: { release(): Promise<void> } | null = null;
	private latches: MilestoneLatches = FRESH_LATCHES;
	nextAfterHold = $state<FocusPhase>('work');

	async init(): Promise<void> {
		if (!browser || this.ticker) return;
		await app.init();
		const [cycle, latches, bestStreak, sessions] = await Promise.all([
			getMetaValue<PersistedCycle>(CYCLE_META_ID),
			getMetaValue<MilestoneLatches>(LATCHES_META_ID),
			getMetaValue<number>(BEST_STREAK_META_ID),
			listSessions()
		]);
		if (cycle) {
			this.cycle = rollPomodoroNumber(cycle, cycle.lastActivityDateKey, dateKey(new Date()));
		}
		this.latches = latches ?? FRESH_LATCHES;
		this.bestStreak = bestStreak ?? 0;
		this.reevaluateStats(sessions);
		this.detectGhost(sessions);
		this.blockMinutes = app.prefs.timeBlockMinutes;
		// A session started from another surface (Plan "Start Focus") must
		// survive this late init — only reset when nothing is live.
		if (!this.session || this.session.status === 'idle') this.resetIdle();
		this.startTicker();
	}

	// ---------- Derived ----------

	phase = $derived<FocusPhase>(this.session?.phase ?? 'work');
	running = $derived(this.session?.status === 'running');
	paused = $derived(this.session?.status === 'paused');
	idle = $derived(!this.session || this.session.status === 'idle');
	/** Mac parity (PhaseColors.swift): break phases derive a calmer variant of
	 * the CURRENT mode color — they never borrow another mode's color.
	 * `app.theme` is read so the derivation re-runs on theme switches
	 * (getComputedStyle is not reactive on its own). */
	phaseColor = $derived.by(() => {
		void app.theme; // tracked dependency: re-derive when the theme changes
		let base = CLASSIC_MODE_HEX[this.mode] ?? '#2eb870';
		if (browser) {
			const v = getComputedStyle(document.documentElement)
				.getPropertyValue(`--mode-${this.mode}`)
				.trim();
			if (/^#[0-9a-fA-F]{3}$|^#[0-9a-fA-F]{6}$/.test(v)) base = v;
		}
		if (this.phase === 'shortBreak') return breakVariant(base, 'short');
		if (this.phase === 'longBreak') return breakVariant(base, 'long');
		return base;
	});
	progress = $derived.by(() => {
		const s = this.session;
		if (!s || s.status === 'idle') return 0;
		const elapsed = liveElapsedMs(s, new Date());
		if (s.targetMs != null && s.targetMs > 0) return Math.min(1, Math.max(0, elapsed / s.targetMs));
		return Math.min(1, elapsed / (25 * 60_000));
	});
	/** Display arc for the ring — Mac TimerCircleView.timerRingProgress
	 * (FocusView.swift:1021): countdown rings start FULL and deplete
	 * (idle/hold show the full ring of the pending phase); count-up rings
	 * fill one 60-minute cycle while running (floor 4%) and show no arc
	 * otherwise — the dashed overlay covers idle/hold/paused. `null` = no
	 * arc layer. */
	ringProgress = $derived.by(() => {
		const s = this.session;
		if (this.mode === 'flowtime' || this.mode === 'stopwatch') {
			// Native keeps the session "running" through pause/hold
			// (FocusFeature:424-427): the arc freezes at the last position.
			// holdFor preserves the ended phase's elapsedMs so the frozen
			// arc survives the hold; liveElapsedMs already freezes paused.
			const frozen = s && (s.status === 'paused' || (this.waiting && s.status === 'idle'));
			if (s && (s.status === 'running' || frozen)) {
				const cycleSeconds = 60 * 60;
				const position = (liveElapsedMs(s, new Date()) / 1000) % cycleSeconds;
				return Math.max(Math.min(position / cycleSeconds, 1), 0.04);
			}
			return null;
		}
		if (!s || s.status === 'idle') return 1;
		return Math.min(Math.max(1 - this.progress, 0), 1);
	});
	beforeLongBreak = $derived(pomodoroConfigFrom(app.prefs).beforeLongBreak);

	// ---------- Mode / phase transitions ----------

	selectMode(mode: FocusMode): void {
		if (this.session && !this.idle) return;
		this.mode = mode;
		this.blockMinutes = app.prefs.timeBlockMinutes;
		this.resetIdle();
	}

	adjustBlock(delta: number): void {
		this.blockMinutes = adjustBlock(this.blockMinutes, delta);
	}

	/** Native parity (iOS extendWorkPhase): +5 minutes to the upcoming work phase. */
	extendHold(minutes = 5): void {
		if (!this.waiting || this.nextAfterHold !== 'work') return;
		// Native parity: extends the PENDING phase cumulatively (iOS
		// extendWorkPhase), capped at 3 hours like TimeBlock.
		const base = this.session?.targetMs ?? this.idleTarget() ?? 0;
		this.session = {
			...this.session!,
			targetMs: Math.min(180 * 60_000, base + minutes * 60_000)
		};
		this.refreshDisplay();
	}

	start(): void {
		primeAudio();
		if (this.waiting) {
			this.waiting = false;
			this.beginPhase(this.nextAfterHold);
			return;
		}
		if (!this.idle) return;
		this.beginPhase('work');
	}

	private beginPhase(phase: FocusPhase, flowWorkMs = 0): void {
		const prefs = app.prefs;
		let targetMs: number | null = null;
		if (this.mode === 'pomodoro') {
			const cfg = pomodoroConfigFrom(prefs);
			targetMs =
				phase === 'work' ? cfg.workMs : phase === 'shortBreak' ? cfg.breakMs : cfg.longBreakMs;
		} else if (this.mode === 'flowtime') {
			targetMs = isBreakPhase(phase)
				? flowtimeBreakMinutes(Math.round(flowWorkMs / 60_000)) * 60_000
				: null;
		} else if (this.mode === 'timeblock' && phase === 'work') {
			targetMs = this.blockMinutes * 60_000;
		}
		this.session = { ...createIdleSession(this.mode, {}), targetMs, phase };
		this.session = startSession(this.session, new Date());
		this.breakSuggested = false;
		this.midpointNotified = false;
		this.persistSession(); // ghost anchor: persisted at phase start
		this.attachSoundscape();
		void this.acquireWakeLock();
		this.refreshDisplay();
	}

	pause(): void {
		if (!this.session || this.session.status !== 'running') return;
		this.session = pauseSession(this.session, new Date());
		this.pausedAt = new Date().toISOString();
		this.persistSession();
		this.detachSoundscape();
		void this.releaseWakeLock();
		this.refreshDisplay();
	}

	resume(): void {
		if (!this.session || this.session.status !== 'paused') return;
		if (this.pausedAt) {
			const gap = Date.now() - new Date(this.pausedAt).getTime();
			this.session = {
				...this.session,
				totalPauseMs: (this.session.totalPauseMs ?? 0) + gap,
				pauseCount: (this.session.pauseCount ?? 0) + 1
			};
			this.pausedAt = null;
		}
		this.session = resumeSession(this.session, new Date());
		this.persistSession();
		this.attachSoundscape();
		void this.acquireWakeLock();
		this.refreshDisplay();
	}

	/** Skip: work → partial-credit record + advance; break → hold for work. */
	skip(): void {
		if (!this.session || this.idle) return;
		const elapsed = liveElapsedMs(this.session, new Date());
		const phase = this.phase;
		this.session = skipSession(this.session, new Date());
		if (phase === 'work') {
			this.recordWork(elapsed, false);
			this.afterWorkEnds(false);
		} else {
			this.afterBreakEnds();
		}
	}

	/** Complete now (manual finish). */
	complete(): void {
		if (!this.session || this.idle) return;
		const elapsed = liveElapsedMs(this.session, new Date());
		const phase = this.phase;
		this.session = completeSession(this.session, new Date());
		if (phase === 'work') {
			this.recordWork(elapsed, true);
			this.afterWorkEnds(true);
		} else {
			this.afterBreakEnds();
		}
	}

	private onTick(fromVisible = false): void {
		const s = this.session;
		if (!s || s.status === 'idle') return;
		const now = new Date();
		this.session = fromVisible ? recomputeOnVisible(s, now) : tickSession(s, now);

		const elapsed = liveElapsedMs(this.session, new Date());
		if (this.mode === 'flowtime' && this.phase === 'work') {
			const minMs = app.prefs.flowtimeMinSessionMinutes * 60_000;
			if (!this.breakSuggested && elapsed >= minMs) this.breakSuggested = true;
		}
		if (
			this.mode === 'timeblock' &&
			this.phase === 'work' &&
			app.prefs.timeBlockMidpointCheckIn &&
			!this.midpointNotified &&
			this.session.targetMs != null &&
			midpointReached(elapsed, this.session.targetMs)
		) {
			this.midpointNotified = true;
			this.notify('midpoint');
		}

		if (this.session.status === 'completed') {
			this.onPhaseAutoCompleted();
			return;
		}
		this.refreshDisplay();
	}

	private onPhaseAutoCompleted(): void {
		const elapsed = this.session?.targetMs ?? 0;
		if (this.phase === 'work') {
			this.recordWork(elapsed, true);
			this.afterWorkEnds(true);
		} else {
			this.afterBreakEnds();
		}
	}

	private afterWorkEnds(completed: boolean): void {
		this.detachSoundscape();
		void this.releaseWakeLock();
		this.playPhaseEndSound();
		this.notify('phase');
		this.persistCycle();
		this.reevaluateStatsSoon();

		if (this.mode === 'flowtime') {
			// Break is user-initiated (suggestion CTA); nothing to schedule.
			return;
		}
		if (this.mode === 'timeblock') {
			this.resetIdle();
			return;
		}

		// Pomodoro: advance the cycle, then hold or auto-start the break.
		const adv = advanceAfterCompletedWork(this.cycle, app.prefs);
		this.cycle = adv.cycle;
		this.nextAfterHold = adv.nextPhase;
		if (completed) this.evaluateCelebrations();
		if (completed && app.prefs.showJournalAfterSession && (this.session?.elapsedMs ?? 0) >= JOURNAL_MIN_MS) {
			this.journalPrompt = { sessionId: this.session!.id };
		}
		if (app.prefs.autoStartBreaks) {
			this.beginPhase(adv.nextPhase);
		} else {
			this.holdFor(adv.nextPhase);
		}
	}

	private afterBreakEnds(): void {
		this.detachSoundscape();
		void this.releaseWakeLock();
		this.playPhaseEndSound();
		this.notify('phase');
		this.cycle = advanceAfterBreak(this.cycle, this.phase);
		this.persistCycle();
		this.reevaluateStatsSoon();

		if (this.mode === 'flowtime') {
			// Native parity: the break always returns to flow.
			this.beginPhase('work');
			return;
		}
		if (app.prefs.autoStartWork) {
			this.beginPhase('work');
		} else {
			this.holdFor('work');
		}
	}

	private holdFor(next: FocusPhase): void {
		this.nextAfterHold = next;
		this.waiting = true;
		// Keep the ended phase's elapsed: idle display reads targetMs only,
		// but the count-up ring freezes at this position during the hold
		// (native isRunning stays true through the hold).
		const frozenMs = this.session ? liveElapsedMs(this.session, new Date()) : 0;
		this.session = { ...createIdleSession(this.mode, {}), phase: next, elapsedMs: frozenMs };
		this.refreshDisplay();
	}

	/** Flowtime: user accepts the break suggestion mid-flow. */
	takeFlowBreak(): void {
		const s = this.session;
		if (!s || s.status === 'idle' || this.phase !== 'work') return;
		const elapsed = liveElapsedMs(s, new Date());
		this.session = completeSession(s, new Date());
		this.recordWork(elapsed, true);
		this.afterWorkEnds(true);
		this.waiting = false;
		this.beginPhase('shortBreak', elapsed);
	}

	private resetIdle(): void {
		this.session = {
			...createIdleSession(this.mode, {}),
			targetMs: this.idleTarget(),
			phase: 'work'
		};
		this.waiting = false;
		this.refreshDisplay();
	}

	private idleTarget(): number | null {
		if (this.mode === 'pomodoro') return pomodoroConfigFrom(app.prefs).workMs;
		if (this.mode === 'timeblock') return this.blockMinutes * 60_000;
		return null;
	}

	// ---------- Records / stats / celebrations ----------

	private recordWork(elapsedMs: number, terminal: boolean): void {
		const s = this.session;
		if (!s || !terminal) return;
		this.session = { ...s, elapsedMs, taskId: this.activeTask?.id ?? null };
		notifyMutation();
		void saveSession($state.snapshot(this.session));
		if (this.session.taskId) void this.bumpLinkedTask(this.session.taskId);
	}

	/** Native parity: a completed work session bumps 🍅 on the linked task. */
	private async bumpLinkedTask(taskId: string): Promise<void> {
		try {
			const tasks = await listAllTasks();
			const t = tasks.find((x) => x.id === taskId);
			if (!t) return;
			await upsertTask({
				...t,
				completedPomodoros: (t.completedPomodoros ?? 0) + 1,
				updatedAt: new Date().toISOString()
			});
		} catch {
			/* non-fatal */
		}
	}

	private reevaluateStatsSoon(): void {
		void listSessions().then((sessions) => this.reevaluateStats(sessions));
	}

	private reevaluateStats(sessions: FocusSession[]): void {
		const stats = buildDailyStats(sessions);
		this.todayStat = stats.find((d) => d.date === dateKey(new Date())) ?? null;
		this.streak = computeStreak(stats);
		const best = computeBestStreak(stats);
		if (best > this.bestStreak) {
			this.bestStreak = best;
			void setMetaValue(BEST_STREAK_META_ID, best);
		}
	}

	private evaluateCelebrations(): void {
		void listSessions().then((sessions) => {
			this.reevaluateStats(sessions);
			const total = sessions.filter(
				(s) => s.status === 'completed' && !isBreakPhase(s.phase ?? 'work')
			).length;
			const latest = this.session?.elapsedMs ?? 0;
			const result = evaluateMilestone(
				{
					totalCompletedSessions: total,
					currentStreakDays: this.streak,
					latestSessionMs: latest
				},
				this.latches
			);
			this.latches = result.latches;
			void setMetaValue(LATCHES_META_ID, result.latches);
			if (result.milestone) {
				this.milestone = result.milestone;
				if (app.prefs.hapticsEnabled) haptic('celebrate');
			} else {
				this.streakRecord =
					app.prefs.celebrateRecordsEnabled && isStreakRecord(this.streak, this.bestStreak);
			}
		});
	}

	// ---------- Ghost session (tab closed mid-run) ----------

	private detectGhost(sessions: FocusSession[]): void {
		const live = sessions.find((s) => s.status === 'running' || s.status === 'paused');
		if (!live || !live.startedAt) return;
		if (Date.now() - new Date(live.startedAt).getTime() > GHOST_MAX_AGE_MS) {
			notifyMutation();
			void saveSession({ ...live, status: 'skipped', completedAt: new Date().toISOString() });
			return;
		}
		this.ghost = live;
	}

	resumeGhost(): void {
		const g = this.ghost;
		if (!g || !g.startedAt) return;
		this.ghost = null;
		this.mode = g.mode;
		if (g.targetMs != null) {
			const elapsedMs = Math.min(
				g.targetMs,
				Math.max(0, Date.now() - new Date(g.startedAt).getTime() - (g.totalPauseMs ?? 0))
			);
			if (elapsedMs >= g.targetMs) {
				// Finished while away: credit it honestly.
				this.session = { ...g, status: 'completed', elapsedMs: g.targetMs, segmentStartedAt: null };
				this.recordWork(g.targetMs, true);
				this.afterWorkEnds(true);
				return;
			}
			this.session = { ...g, status: 'running', elapsedMs, segmentStartedAt: new Date().toISOString() };
		} else {
			this.session = { ...g, status: 'running', segmentStartedAt: new Date().toISOString() };
		}
		this.attachSoundscape();
		this.refreshDisplay();
	}

	discardGhost(): void {
		const g = this.ghost;
		if (!g) return;
		this.ghost = null;
		const elapsed = liveElapsedMs(g, new Date());
		notifyMutation();
		void saveSession({
			...g,
			status: 'skipped',
			elapsedMs: Math.min(elapsed, g.targetMs ?? elapsed),
			completedAt: new Date().toISOString()
		});
		this.reevaluateStatsSoon();
	}

	// ---------- Task linking ----------

	setActiveTask(task: Task | null): void {
		this.activeTask = task;
		if (this.session && (this.session.status === 'running' || this.session.status === 'paused')) {
			this.session = { ...this.session, taskId: task?.id ?? null };
			this.persistSession();
		}
	}

	// ---------- Journal ----------

	saveJournal(rating: 1 | 2 | 3 | 4 | 5, note: string): void {
		const p = this.journalPrompt;
		if (!p) return;
		this.journalPrompt = null;
		void listSessions().then(async (sessions) => {
			const rec = sessions.find((s) => s.id === p.sessionId);
			if (rec) {
				notifyMutation();
				await saveSession({ ...rec, journal: note, satisfactionRating: rating });
			}
		});
	}

	dismissJournal(): void {
		this.journalPrompt = null;
	}

	dismissMilestone(): void {
		this.milestone = null;
	}

	dismissStreakRecord(): void {
		this.streakRecord = false;
	}

	// ---------- Notifications ----------

	async requestNotifications(): Promise<boolean> {
		if (!browser || !('Notification' in window)) return false;
		if (Notification.permission === 'granted') return true;
		const result = await Notification.requestPermission();
		return result === 'granted';
	}

	private notify(kind: 'phase' | 'midpoint'): void {
		if (!browser || !app.prefs.notificationsEnabled || !('Notification' in window)) return;
		if (Notification.permission !== 'granted') return;
		const body =
			kind === 'midpoint' ? '⏱️ Mitad del bloque — check-in' : '✅ Fase completada — Pepinillo';
		try {
			new Notification('Pepinillo', { body, tag: 'pepinillo-focus' });
		} catch {
			/* notification failures are non-fatal */
		}
	}

	// ---------- Soundscapes ----------

	private attachSoundscape(): void {
		const name = app.prefs.soundscape;
		if (name === 'none' || !this.running) return;
		this.detachSoundscape();
		this.soundscape = startSoundscape(name, app.prefs.soundscapeVolume);
	}

	private detachSoundscape(): void {
		this.soundscape?.stop();
		this.soundscape = null;
	}

	soundscapeChanged(): void {
		if (this.running) this.attachSoundscape();
	}

	private playPhaseEndSound(): void {
		if (!app.prefs.soundEnabled) return;
		playCompletionSound(app.prefs.completionSound, 1);
		if (app.prefs.hapticsEnabled) haptic('success');
	}

	// ---------- WakeLock ----------

	private async acquireWakeLock(): Promise<void> {
		if (!app.prefs.keepScreenOn || !this.running) return;
		try {
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
			const wl = (navigator as any).wakeLock;
			if (wl) this.wakeLock = await wl.request('screen');
		} catch {
			/* wake lock is best-effort */
		}
	}

	private async releaseWakeLock(): Promise<void> {
		try {
			await this.wakeLock?.release();
		} catch {
			/* already released */
		}
		this.wakeLock = null;
	}

	// ---------- Ticker / display ----------

	private startTicker(): void {
		this.stopTicker();
		this.ticker = setInterval(() => this.onTick(), 250);
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'visible') this.onTick(true);
		});
	}

	private stopTicker(): void {
		if (this.ticker) clearInterval(this.ticker);
		this.ticker = null;
	}

	private persistSession(): void {
		if (!this.session) return;
		notifyMutation();
		void saveSession($state.snapshot(this.session));
	}

	private persistCycle(): void {
		const persisted: PersistedCycle = $state.snapshot({
			...this.cycle,
			lastActivityDateKey: dateKey(new Date())
		});
		void setMetaValue(CYCLE_META_ID, persisted);
	}

	private refreshDisplay(): void {
		const s = this.session;
		if (!s || s.status === 'idle') {
			this.displayTime = formatMs(s?.targetMs ?? 0);
		} else if (s.targetMs != null) {
			this.displayTime = formatMs(remainingMs(s, new Date()) ?? 0);
		} else {
			this.displayTime = formatMs(liveElapsedMs(s, new Date()));
		}
		if (browser) {
			const active = s && (s.status === 'running' || s.status === 'paused');
			document.title = active
				? `${this.displayTime} · ${isBreakPhase(this.phase) ? 'Break' : 'Focus'} — Pepinillo`
				: 'Pepinillo';
		}
	}
}

export const focus = new FocusController();
