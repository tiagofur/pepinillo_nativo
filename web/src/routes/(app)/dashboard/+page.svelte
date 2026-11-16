<script lang="ts">
	import { onMount } from 'svelte';
	import { dashboard } from '$lib/stores/dashboard.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import Charts from '$lib/features/dashboard/Charts.svelte';
	import Panels from '$lib/features/dashboard/Panels.svelte';
	import AiCard from '$lib/features/dashboard/AiCard.svelte';
	import ReviewSheet from '$lib/features/dashboard/ReviewSheet.svelte';
	import type { AnalyticsPeriod } from '$lib/domain/dashboard/stats';

	onMount(() => {
		void dashboard.init();
	});

	const PERIODS: { days: AnalyticsPeriod; key: MessageKey }[] = [
		{ days: 7, key: 'period.7' },
		{ days: 30, key: 'period.30' },
		{ days: 365, key: 'period.365' }
	];

	const QUALIFIER_KEYS: Record<string, MessageKey> = {
		exceptional: 'score.exceptional',
		strong: 'score.strong',
		steady: 'score.steady',
		warming: 'score.warming',
		rest: 'score.rest'
	};

	function fmtMin(seconds: number): string {
		const m = Math.round(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}

	function hourLabel(h: number | null): string {
		if (h === null) return '—';
		return `${String(h).padStart(2, '0')}:00`;
	}
</script>

<svelte:head>
	<title>{t('dashboard.title')} · Pepinillo</title>
</svelte:head>

<section class="dash rise-in">
	<header class="head">
		<h1>{t('dashboard.title')}</h1>
		<div class="head-actions">
			<button class="btn btn-soft pressable" onclick={() => dashboard.openReview(7)}>
				📊 {t('review.weekly')}
			</button>
			<button class="btn btn-ghost pressable" onclick={() => dashboard.openReview(30)}>
				{t('review.monthly')}
			</button>
		</div>
	</header>

	{#if dashboard.stats}
		<!-- Streak hero -->
		<div class="hero card">
			<div class="streak">
				<span class="streak-num nums">{dashboard.stats.streak > 0 ? `🔥 ${dashboard.stats.streak}` : '—'}</span>
				<span class="streak-label">{t('companion.streak')}</span>
				<span class="streak-best">{t('dash.best', { days: dashboard.stats.bestStreak })}</span>
			</div>
			<div class="score">
				<span class="score-num nums">{dashboard.stats.focusScore}</span>
				<span class="score-label">{t(QUALIFIER_KEYS[dashboard.stats.focusScoreQualifier])}</span>
				<span class="score-name">{t('dash.focusScore')}</span>
			</div>
			<div class="patterns">
				<div class="pattern">
					<span class="p-icon">⏰</span>
					<span class="p-value nums">{hourLabel(dashboard.stats.peakHour)}</span>
					<span class="p-label">{t('dash.peakHour')}</span>
				</div>
				<div class="pattern">
					<span class="p-icon">📈</span>
					<span class="p-value nums">{Math.round(dashboard.stats.completionRate * 100)}%</span>
					<span class="p-label">{t('dash.completion')}</span>
				</div>
				<div class="pattern">
					<span class="p-icon">🤿</span>
					<span class="p-value nums">{fmtMin(dashboard.stats.longestSessionMs / 1000)}</span>
					<span class="p-label">{t('dash.longest')}</span>
				</div>
			</div>
		</div>

		<!-- Summary cards -->
		<div class="summary">
			<div class="card stat">
				<span class="v nums">{fmtMin(dashboard.stats.todayFocusSeconds)}</span>
				<span class="l">{t('companion.focusToday')}</span>
			</div>
			<div class="card stat">
				<span class="v nums">{dashboard.stats.todaySessions}</span>
				<span class="l">{t('companion.sessionsToday')}</span>
			</div>
			<div class="card stat">
				<span class="v nums">{fmtMin(dashboard.stats.periodFocusSeconds)}</span>
				<span class="l">{t('dash.periodFocus')}</span>
			</div>
			<div class="card stat">
				<span class="v nums">{dashboard.unlockedCount}/6</span>
				<span class="l">{t('achievements.title')}</span>
			</div>
		</div>

		<!-- Period picker -->
		<div class="pills">
			{#each PERIODS as p (p.days)}
				{@const gated = dashboard.periodGated(p.days)}
				<button
					class="chip pressable"
					aria-pressed={dashboard.period === p.days}
					class:is-active={dashboard.period === p.days}
					class:is-locked={gated}
					disabled={gated}
					onclick={() => dashboard.setPeriod(p.days)}
					title={gated ? t('common.proLocked') : ''}
				>
					{#if gated}🔒{/if}
					{t(p.key)}
				</button>
			{/each}
		</div>

		<Charts stats={dashboard.stats} periodDays={dashboard.period} />

		<AiCard />

		<Panels achievements={dashboard.achievements} sessions={dashboard.sessions} />

		<ReviewSheet />
	{:else}
		<div class="card empty">
			<p>{t('dashboard.empty')}</p>
		</div>
	{/if}
</section>

<style>
	.dash {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		max-width: 860px;
		margin-inline: auto;
		width: 100%;
	}

	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		flex-wrap: wrap;
	}

	h1 {
		font-size: var(--text-xl);
	}

	.head-actions {
		display: flex;
		gap: var(--space-2);
	}

	.hero {
		display: grid;
		grid-template-columns: auto auto;
		gap: var(--space-5) var(--space-8);
		padding: var(--space-6);
	}

	.streak,
	.score {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.streak-num,
	.score-num {
		font-size: clamp(2rem, 5vw, 2.8rem);
		font-weight: 800;
		letter-spacing: var(--tracking-tight);
	}

	.streak-num {
		color: var(--streak);
	}

	.score-num {
		color: var(--brand);
	}

	.streak-label,
	.score-label {
		font-weight: 650;
		color: var(--ink-secondary);
	}

	.streak-best,
	.score-name {
		font-size: var(--text-xs);
		color: var(--faint);
	}

	.patterns {
		grid-column: 1 / -1;
		display: flex;
		gap: var(--space-6);
		flex-wrap: wrap;
	}

	.pattern {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.p-value {
		font-weight: 700;
	}

	.p-label {
		font-size: var(--text-xs);
		color: var(--faint);
	}

	.summary {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
		gap: var(--space-3);
	}

	.stat {
		padding: var(--space-4);
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.v {
		font-size: var(--text-lg);
		font-weight: 700;
	}

	.l {
		font-size: var(--text-xs);
		color: var(--muted);
		font-weight: 600;
	}

	.pills {
		display: flex;
		gap: var(--space-2);
	}

	.empty {
		padding: var(--space-10);
		text-align: center;
		color: var(--muted);
	}

	@media (max-width: 599px) {
		.hero {
			grid-template-columns: 1fr 1fr;
			gap: var(--space-4);
		}

		.patterns {
			gap: var(--space-4);
		}
	}
</style>
