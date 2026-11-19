/**
 * DashboardStore — feeds the Dashboard page from local records.
 * Free tier: analytics limited to today + last 7 days (recovered gate);
 * the period picker exposes 30D/365D only for Pepinillo+/Everywhere+.
 */
import { browser } from '$app/environment';
import { listAllTasks, listSessions } from '$lib/data/local/idb';
import { computeDashboardStats, type AnalyticsPeriod, type DashboardStats } from '$lib/domain/dashboard/stats';
import { evaluateAchievements, type Achievement } from '$lib/domain/achievements/achievements';
import { buildPeriodReview, type PeriodReview } from '$lib/domain/reviews/reviews';
import { canUseAnalyticsPeriod } from '$lib/domain/gates/freeLimits';
import { isWorkPhase } from '$lib/domain/stats/daily';
import { localDateKey } from '$lib/domain/tasks/recurrence';
import { app } from '$lib/stores/app.svelte';
import { plan } from '$lib/stores/plan.svelte';
import type { FocusSession, Task } from '$lib/domain/entities/types';

class DashboardStore {
	loaded = $state(false);
	stats = $state<DashboardStats | null>(null);
	achievements = $state<Achievement[]>([]);
	review = $state<PeriodReview | null>(null);
	reviewOpen = $state(false);
	reviewKind = $state<7 | 30>(7);
	sessions = $state<FocusSession[]>([]);
	tasks = $state<Task[]>([]);

	period = $state<AnalyticsPeriod>(7);

	private allSessions: FocusSession[] = [];

	async init(): Promise<void> {
		if (!browser) return;
		await app.init();
		await plan.init();
		await this.reload();
		this.loaded = true;
	}

	async reload(): Promise<void> {
		this.allSessions = await listSessions();
		this.tasks = await listAllTasks();
		// History panel lists work sessions only (breaks are noise).
		this.sessions = this.allSessions.filter((s) => isWorkPhase(s.phase)).slice(0, 20);
		this.recompute();
	}

	setPeriod(period: AnalyticsPeriod): void {
		if (!canUseAnalyticsPeriod(period, app.tier)) return;
		this.period = period;
		this.recompute();
	}

	private recompute(): void {
		const now = new Date();
		this.stats = computeDashboardStats(this.allSessions, now, this.period);
		this.achievements = evaluateAchievements(this.allSessions, now);
		this.review = buildPeriodReview(this.allSessions, this.tasks, now, this.reviewKind);
	}

	openReview(kind: 7 | 30): void {
		this.reviewKind = kind;
		this.review = buildPeriodReview(this.allSessions, this.tasks, new Date(), kind);
		this.reviewOpen = true;
	}

	closeReview(): void {
		this.reviewOpen = false;
	}

	unlockedCount = $derived(this.achievements.filter((a) => a.unlocked).length);

	/** Mac Today "Tasks Completed" KPI (MacTodayView:138-168). */
	tasksCompletedToday = $derived.by(() => {
		const todayKey = localDateKey(new Date());
		return this.tasks.filter(
			(t) => t.status === 'completed' && t.completedAt && localDateKey(new Date(t.completedAt)) === todayKey
		).length;
	});

	/** Mac nextFocusCard: first scheduled-for-today active task by priority
	 * then order (MacTodayView:31-40). */
	nextTask = $derived.by(() => {
		const todayKey = localDateKey(new Date());
		const PRIORITY_RANK: Record<string, number> = { high: 3, medium: 2, low: 1, none: 0 };
		return (
			this.tasks
				.filter(
					(t) =>
						t.status === 'active' &&
						(t.scheduledForToday === true || t.dueDate === todayKey)
				)
				.sort((a, b) => {
					const pa = PRIORITY_RANK[a.priority] ?? 0;
					const pb = PRIORITY_RANK[b.priority] ?? 0;
					if (pa !== pb) return pb - pa;
					return a.order - b.order;
				})[0] ?? null
		);
	});

	periodGated(period: AnalyticsPeriod): boolean {
		return !canUseAnalyticsPeriod(period, app.tier);
	}
}

export const dashboard = new DashboardStore();
