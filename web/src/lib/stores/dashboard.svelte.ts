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

	periodGated(period: AnalyticsPeriod): boolean {
		return !canUseAnalyticsPeriod(period, app.tier);
	}
}

export const dashboard = new DashboardStore();
