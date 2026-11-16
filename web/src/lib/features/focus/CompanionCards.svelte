<script lang="ts">
	import { focus } from '$lib/stores/focus.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import { suggestMode } from '$lib/domain/intelligence/modeSuggest';
	import { FREE_MODES } from '$lib/domain/entities/types';

	const suggestion = suggestMode();
	let suggestionLocked = $derived(!(FREE_MODES as readonly string[]).includes(suggestion.mode));

	function fmtSeconds(sec: number): string {
		const m = Math.floor(sec / 60);
		if (m < 60) return `${m}m`;
		const h = Math.floor(m / 60);
		return `${h}h ${m % 60}m`;
	}
</script>

<div class="cards">
	{#if focus.todayStat}
		<div class="card stat">
			<span class="value nums">{fmtSeconds(focus.todayStat.totalFocusSeconds)}</span>
			<span class="label">{t('companion.focusToday')}</span>
		</div>
		<div class="card stat">
			<span class="value nums">{focus.todayStat.sessionsCompleted}</span>
			<span class="label">{t('companion.sessionsToday')}</span>
		</div>
	{:else}
		<div class="card stat">
			<span class="value nums">0m</span>
			<span class="label">{t('companion.focusToday')}</span>
		</div>
		<div class="card stat">
			<span class="value nums">0</span>
			<span class="label">{t('companion.sessionsToday')}</span>
		</div>
	{/if}

	<div class="card stat">
		<span class="value nums">{focus.streak > 0 ? `🔥 ${focus.streak}` : '—'}</span>
		<span class="label">{t('companion.streak')}</span>
	</div>

	<div class="card stat">
		<span class="value nums">
			🍅 {focus.cycle.pomodoroNumber}
		</span>
		<span class="label">{t('companion.pomodoroNumber')}</span>
	</div>

	{#if focus.activeTask}
		<div class="card task-card">
			<span class="label">{t('companion.activeTask')}</span>
			<span class="task-title">{focus.activeTask.title}</span>
		</div>
	{/if}

	<button
		class="card suggest pressable"
		onclick={() => focus.selectMode(suggestion.mode)}
		disabled={suggestionLocked}
		title={suggestionLocked ? t('common.proLocked') : t('companion.suggest.apply')}
	>
		<span class="label">{t('companion.suggest.title')}</span>
		<span class="task-title">
			{t(`focus.mode.${suggestion.mode}`)} — {t(`focus.suggest.${suggestion.reasonKey}`)}
			{#if suggestionLocked}🔒{/if}
		</span>
	</button>
</div>

<style>
	.cards {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
		gap: var(--space-3);
		width: min(560px, 100%);
	}

	.card {
		padding: var(--space-4);
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.value {
		font-size: var(--text-lg);
		font-weight: 700;
		letter-spacing: var(--tracking-tight);
	}

	.label {
		color: var(--muted);
		font-size: var(--text-xs);
		font-weight: 600;
	}

	.task-card .task-title,
	.suggest .task-title {
		font-weight: 650;
		font-size: var(--text-sm);
	}

	.suggest {
		cursor: pointer;
		text-align: start;
	}

	.suggest:disabled {
		cursor: not-allowed;
		color: var(--faint);
	}
</style>
