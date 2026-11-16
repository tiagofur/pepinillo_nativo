<script lang="ts">
	import Sheet from '$lib/design/Sheet.svelte';
	import { dashboard } from '$lib/stores/dashboard.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import type { FocusMode } from '$lib/domain/entities/types';

	const MODE_KEYS: Record<FocusMode, MessageKey> = {
		pomodoro: 'focus.mode.pomodoro',
		flowtime: 'focus.mode.flowtime',
		timeblock: 'focus.mode.timeblock',
		stopwatch: 'focus.mode.stopwatch'
	};

	const DAY_KEYS: MessageKey[] = [
		'chart.day.sun',
		'chart.day.mon',
		'chart.day.tue',
		'chart.day.wed',
		'chart.day.thu',
		'chart.day.fri',
		'chart.day.sat'
	];

	function fmtMin(seconds: number): string {
		const m = Math.round(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}

	function setKind(kind: 7 | 30): void {
		dashboard.openReview(kind);
	}
</script>

<Sheet open={dashboard.reviewOpen} onclose={() => dashboard.closeReview()} title={t(dashboard.reviewKind === 7 ? 'review.weekly' : 'review.monthly')}>
	{#if dashboard.review}
		<div class="tabs">
			<button class="chip pressable is-active" aria-pressed="true">{t('review.dataTab')}</button>
			<button
				class="chip pressable"
				onclick={() => dashboard.closeReview()}
				title={t('review.aiSoon')}
			>
				🤖 {t('review.aiTab')}
			</button>
		</div>

		<div class="grid">
			<div class="metric">
				<span class="value nums">{fmtMin(dashboard.review.focusSeconds)}</span>
				<span class="label">{t('review.focus')}</span>
			</div>
			<div class="metric">
				<span class="value nums">{dashboard.review.sessionsCompleted}</span>
				<span class="label">{t('review.sessions')}</span>
			</div>
			<div class="metric">
				<span class="value nums">{dashboard.review.streakDays}</span>
				<span class="label">{t('companion.streak')}</span>
			</div>
		</div>

		<div class="trend" class:up={dashboard.review.trend === 'up'} class:down={dashboard.review.trend === 'down'}>
			{#if dashboard.review.trend === 'up'}
				↗ {t('review.trendUp', { pct: Math.round(dashboard.review.trendPct * 100) })}
			{:else if dashboard.review.trend === 'down'}
				↘ {t('review.trendDown', { pct: Math.round(dashboard.review.trendPct * 100) })}
			{:else}
				→ {t('review.trendFlat')}
			{/if}
		</div>

		{#if dashboard.review.topTasks.length > 0}
			<div class="section">
				<h3>{t('review.topTasks')}</h3>
				<ul class="tasks">
					{#each dashboard.review.topTasks as line (line.taskId)}
						<li>
							<span class="t-title">{line.title}</span>
							<span class="nums muted">{line.sessions} · {fmtMin(line.seconds)}</span>
						</li>
					{/each}
				</ul>
			</div>
		{/if}

		{#if dashboard.review.modeDistribution.length > 0}
			<div class="section">
				<h3>{t('review.modes')}</h3>
				<p class="muted">
					{dashboard.review.modeDistribution
						.map((m) => `${t(MODE_KEYS[m.mode])} ${Math.round(m.pct * 100)}%`)
						.join(' · ')}
				</p>
			</div>
		{/if}

		{#if dashboard.review.bestDay !== null}
			<p class="muted">📅 {t('review.bestDay')} {t(DAY_KEYS[dashboard.review.bestDay])}</p>
		{/if}

		<p class="kind-switch">
			<button class="chip pressable" class:is-active={dashboard.reviewKind === 7} onclick={() => setKind(7)}>
				{t('review.weekly')}
			</button>
			<button class="chip pressable" class:is-active={dashboard.reviewKind === 30} onclick={() => setKind(30)}>
				{t('review.monthly')}
			</button>
		</p>
	{/if}
</Sheet>

<style>
	.tabs {
		display: flex;
		gap: var(--space-2);
		margin-bottom: var(--space-4);
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-3);
	}

	.metric {
		display: flex;
		flex-direction: column;
		gap: 2px;
		background: var(--surface-alt);
		border-radius: var(--radius-md);
		padding: var(--space-3);
	}

	.value {
		font-size: var(--text-lg);
		font-weight: 700;
	}

	.label {
		font-size: var(--text-2xs);
		color: var(--muted);
		font-weight: 600;
	}

	.trend {
		font-weight: 650;
		padding: var(--space-2) var(--space-3);
		border-radius: var(--radius-md);
		background: var(--surface-alt);
		color: var(--muted);
		width: fit-content;
	}

	.trend.up {
		color: var(--brand);
		background: var(--brand-soft);
	}

	.trend.down {
		color: var(--mode-pomodoro);
		background: var(--mode-pomodoro-soft);
	}

	.section h3 {
		font-size: var(--text-sm);
		color: var(--muted);
		margin: 0 0 var(--space-2);
	}

	.tasks {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.tasks li {
		display: flex;
		justify-content: space-between;
		gap: var(--space-3);
	}

	.t-title {
		font-weight: 550;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.muted {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.kind-switch {
		display: flex;
		gap: var(--space-2);
		margin-top: var(--space-2);
	}
</style>
