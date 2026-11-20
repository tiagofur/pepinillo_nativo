/**
 * AIStore — Everywhere+ AI surfaces over the backend /ai/* endpoints.
 * Free users never call the API: surfaces render the gated state directly.
 * Errors map the contract envelopes (402 ERR_TIER_INSUFFICIENT /
 * 403 feature_not_available) to a gated state with an upgrade CTA.
 */
import { auth } from '$lib/stores/auth.svelte';
import { app } from '$lib/stores/app.svelte';

export type AiStatus = 'idle' | 'loading' | 'ready' | 'gated' | 'error' | 'offline';

interface AiState<T> {
	status: AiStatus;
	data: T | null;
}

function initialState<T>(): AiState<T> {
	return { status: 'idle', data: null };
}

class AIStore {
	dailyTip = $state<AiState<string>>(initialState<string>());
	burnoutRisk = $state<AiState<{ level: string; summary: string } | null>>(initialState());
	optimalHours = $state<AiState<{ windows: string[] } | null>>(initialState());
	weeklyInsights = $state<AiState<{ highlights: string[]; insights: string[] } | null>>(initialState());

	/** Cloud AI runs on the backend, which denies ai_insights for
	 * pepinillo_plus (#952) — Everywhere/AI+ only. */
	get isPremium(): boolean {
		return app.tier === 'everywhere' && auth.user !== null;
	}

	private get api() {
		return auth.api;
	}

	/** Daily tip for the dashboard card. */
	async loadDailyTip(): Promise<void> {
		if (!this.isPremium) {
			this.dailyTip = { status: 'gated', data: null };
			return;
		}
		if (this.dailyTip.status === 'ready') return;
		this.dailyTip = { status: 'loading', data: null };
		try {
			const res = await this.api!.aiDailyTip();
			this.dailyTip = { status: 'ready', data: res.tip ?? res.message ?? '' };
		} catch {
			this.dailyTip = { status: this.gateOrError(), data: null };
		}
	}

	async loadBurnoutRisk(): Promise<void> {
		if (!this.isPremium) {
			this.burnoutRisk = { status: 'gated', data: null };
			return;
		}
		if (this.burnoutRisk.status === 'ready') return;
		this.burnoutRisk = { status: 'loading', data: null };
		try {
			const res = await this.api!.aiBurnoutRisk();
			this.burnoutRisk = { status: 'ready', data: res };
		} catch {
			this.burnoutRisk = { status: this.gateOrError(), data: null };
		}
	}

	async loadOptimalHours(): Promise<void> {
		if (!this.isPremium) {
			this.optimalHours = { status: 'gated', data: null };
			return;
		}
		if (this.optimalHours.status === 'ready') return;
		this.optimalHours = { status: 'loading', data: null };
		try {
			const res = await this.api!.aiOptimalHours();
			this.optimalHours = { status: 'ready', data: res };
		} catch {
			this.optimalHours = { status: this.gateOrError(), data: null };
		}
	}

	/** Weekly report insights for the review sheet AI tab. */
	async loadWeeklyInsights(): Promise<void> {
		if (!this.isPremium) {
			this.weeklyInsights = { status: 'gated', data: null };
			return;
		}
		this.weeklyInsights = { status: 'loading', data: null };
		try {
			const res = await this.api!.aiWeeklyReport();
			this.weeklyInsights = {
				status: 'ready',
				data: {
					highlights: res.highlights ?? [],
					insights: res.insights ?? res.recommendations ?? []
				}
			};
		} catch {
			this.weeklyInsights = { status: this.gateOrError(), data: null };
		}
	}

	private gateOrError(): AiStatus {
		if (!auth.configured) return 'offline';
		if (app.tier !== 'everywhere') return 'gated';
		return 'error';
	}

	/** Reset surfaces to idle (idempotent: only writes when needed). */
	reset(): void {
		if (this.dailyTip.status !== 'idle') this.dailyTip = initialState<string>();
		if (this.burnoutRisk.status !== 'idle') this.burnoutRisk = initialState();
		if (this.optimalHours.status !== 'idle') this.optimalHours = initialState();
		if (this.weeklyInsights.status !== 'idle') this.weeklyInsights = initialState();
	}

	/** Mark all surfaces gated (free tier or signed-out). Idempotent. */
	markGated(): void {
		if (this.dailyTip.status === 'idle' || this.dailyTip.status === 'loading') {
			this.dailyTip = { status: 'gated', data: null };
		}
		if (this.burnoutRisk.status === 'idle' || this.burnoutRisk.status === 'loading') {
			this.burnoutRisk = { status: 'gated', data: null };
		}
		if (this.optimalHours.status === 'idle' || this.optimalHours.status === 'loading') {
			this.optimalHours = { status: 'gated', data: null };
		}
		if (this.weeklyInsights.status === 'idle' || this.weeklyInsights.status === 'loading') {
			this.weeklyInsights = { status: 'gated', data: null };
		}
	}
}

export const ai = new AIStore();
