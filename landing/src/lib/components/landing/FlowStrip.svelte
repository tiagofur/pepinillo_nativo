<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	const FLOW: { key: MessageKey; emoji: string }[] = [
		{ key: 'landing.flow.plan', emoji: '🗂️' },
		{ key: 'landing.flow.focus', emoji: '🎯' },
		{ key: 'landing.flow.complete', emoji: '✅' },
		{ key: 'landing.flow.reflect', emoji: '🌱' }
	];
</script>

<section class="flow" aria-label={t('landing.flow.label')}>
	{#each FLOW as step, i (step.key)}
		<div class="flow-step" style="--step-delay: {i * 90}ms">
			<span class="flow-emoji">{step.emoji}</span>
			<span class="flow-name">{t(step.key)}</span>
			{#if i < FLOW.length - 1}
				<span class="flow-arrow" aria-hidden="true">→</span>
			{/if}
		</div>
	{/each}
</section>

<style>
	.flow {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		flex-wrap: wrap;
		justify-content: center;
		padding: var(--space-5) var(--space-6);
		border-block: 1px solid var(--hairline);
	}

	.flow-step {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		animation: rise-in var(--dur-slow) var(--ease-out-quint) both;
		animation-delay: var(--step-delay);
	}

	.flow-emoji {
		font-size: 22px;
	}

	.flow-name {
		font-weight: 650;
		color: var(--ink-secondary);
	}

	.flow-arrow {
		color: var(--faint);
		margin-inline-start: var(--space-2);
	}

	@keyframes rise-in {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}
</style>
