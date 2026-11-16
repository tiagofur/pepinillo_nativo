<script lang="ts">
	import { ai } from '$lib/stores/ai.svelte';
	import { t } from '$lib/i18n/i18n.svelte';

	// Reactive to session restore: load once premium (or re-gate on sign-out).
	// queueMicrotask keeps the async loads outside this effect's dependency
	// tracking (they write the same state the effect would otherwise read).
	$effect(() => {
		const premium = ai.isPremium;
		queueMicrotask(() => {
			if (premium) {
				void ai.loadDailyTip();
				void ai.loadOptimalHours();
				void ai.loadBurnoutRisk();
			} else {
				ai.markGated();
			}
		});
	});
</script>

<div class="card ai-card">
	<h3>🤖 {t('ai.cardTitle')}</h3>

	{#if ai.dailyTip.status === 'gated' || ai.dailyTip.status === 'offline'}
		<div class="gated">
			<p>🔒 {t('ai.gated')}</p>
			<a class="btn btn-soft pressable" href="/upgrade">{t('ai.upgradeCta')}</a>
		</div>
	{:else}
		{#if ai.dailyTip.status === 'ready' && ai.dailyTip.data}
			<p class="tip">💡 {ai.dailyTip.data}</p>
		{:else if ai.dailyTip.status === 'loading'}
			<p class="muted">{t('ai.loading')}</p>
		{/if}

		{#if ai.optimalHours.status === 'ready' && ai.optimalHours.data?.windows?.length}
			<div class="row">
				<span class="label">⏰ {t('ai.optimalHours')}</span>
				<span class="nums">{ai.optimalHours.data.windows.join(' · ')}</span>
			</div>
		{/if}

		{#if ai.burnoutRisk.status === 'ready' && ai.burnoutRisk.data?.summary}
			<div class="row">
				<span class="label">🩺 {t('ai.burnout')}</span>
				<span class="badge badge-soft">{ai.burnoutRisk.data.level}</span>
				<span class="muted summary">{ai.burnoutRisk.data.summary}</span>
			</div>
		{/if}
	{/if}
</div>

<style>
	.ai-card {
		padding: var(--space-5);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	h3 {
		font-size: var(--text-sm);
		font-weight: 700;
		color: var(--muted);
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	.tip {
		font-weight: 550;
		color: var(--ink);
	}

	.muted {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		flex-wrap: wrap;
		font-size: var(--text-sm);
	}

	.label {
		color: var(--muted);
		font-weight: 600;
	}

	.summary {
		flex: 1;
		min-width: 0;
	}

	.gated {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		align-items: flex-start;
		color: var(--muted);
		background: var(--surface-alt);
		border-radius: var(--radius-md);
		padding: var(--space-4);
	}

	.gated .btn {
		align-self: flex-start;
	}
</style>
