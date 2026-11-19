<script lang="ts">
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import { suggestMode } from '$lib/domain/intelligence/modeSuggest';
	import { FREE_MODES } from '$lib/domain/entities/types';

	const suggestion = suggestMode();
	let suggestionUsable = $derived((FREE_MODES as readonly string[]).includes(suggestion.mode));

	function fmtSeconds(sec: number): string {
		const m = Math.floor(sec / 60);
		if (m < 60) return `${m}m`;
		const h = Math.floor(m / 60);
		return `${h}h ${m % 60}m`;
	}

	// Mac Focus stage parity (MacFocusView.todayStats): ONE value-first slim
	// line — "N sessions · N min · N days streak" — under the controls, no
	// cards. The pomodoro counter was removed from the stage (#789).
	let stats = $derived.by(() => {
		const sessions = focus.todayStat?.sessionsCompleted ?? 0;
		const minutes = Math.round((focus.todayStat?.totalFocusSeconds ?? 0) / 60);
		const streak = focus.streak;
		return [
			{
				value: sessions,
				label: sessions === 1 ? t('companion.stat.session') : t('companion.stat.sessions')
			},
			{ value: minutes, label: t('companion.stat.min') },
			{
				value: streak > 0 ? streak : '—',
				label: streak === 1 ? t('companion.stat.daystreak1') : t('companion.stat.daystreak')
			}
		];
	});
</script>

<div class="statline">
	{#each stats as s, i (i)}
		<span class="stat">
			<span class="stat-value nums">{s.value}</span>
			<span class="stat-label">{s.label}</span>
		</span>
	{/each}
</div>

{#if focus.activeTask}
	<p class="task-line">
		<span class="task-label">{t('companion.activeTask')}</span>
		<span class="task-title">{focus.activeTask.title}</span>
	</p>
{/if}

{#if suggestionUsable}
	<button
		class="suggest-line pressable"
		onclick={() => focus.selectMode(suggestion.mode)}
		title={t('companion.suggest.apply')}
	>
		<span class="suggest-label">{t('companion.suggest.title')}:</span>
		<span class="suggest-value">{t(`focus.suggest.${suggestion.reasonKey}`)}</span>
	</button>
{/if}

<style>
	/* Mac Focus stage: one slim stat line — quiet surfaces, no cards */
	.statline {
		display: flex;
		align-items: baseline;
		justify-content: center;
		gap: var(--space-5);
		flex-wrap: wrap;
		width: min(560px, 100%);
	}

	.stat {
		display: inline-flex;
		align-items: baseline;
		gap: var(--space-2);
	}

	.stat-label {
		font-size: var(--text-xs);
		color: var(--muted);
		font-weight: 600;
	}

	.stat-value {
		font-family: var(--font-rounded);
		font-size: var(--text-base);
		font-weight: 650;
		color: var(--ink-secondary);
		font-variant-numeric: tabular-nums;
	}

	.task-line {
		margin: 0;
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
		font-size: var(--text-sm);
	}

	.task-label {
		color: var(--muted);
		font-weight: 600;
	}

	.task-title {
		font-weight: 650;
		color: var(--ink);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		max-width: 40ch;
	}

	.suggest-line {
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
		border: none;
		background: none;
		padding: var(--space-1) var(--space-2);
		border-radius: var(--radius-sm);
		cursor: pointer;
		font-size: var(--text-sm);
	}

	.suggest-line:hover {
		background: var(--brand-softer);
	}

	.suggest-label {
		color: var(--muted);
		font-weight: 600;
	}

	.suggest-value {
		color: var(--brand);
		font-weight: 650;
	}
</style>
