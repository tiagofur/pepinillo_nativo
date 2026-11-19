<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	const FAQ: { q: MessageKey; a: MessageKey }[] = [
		{ q: 'landing.faq.offline.q', a: 'landing.faq.offline.a' },
		{ q: 'landing.faq.devices.q', a: 'landing.faq.devices.a' },
		{ q: 'landing.faq.price.q', a: 'landing.faq.price.a' },
		{ q: 'landing.faq.account.q', a: 'landing.faq.account.a' },
		{ q: 'landing.faq.sync.q', a: 'landing.faq.sync.a' },
		{ q: 'landing.faq.ai.q', a: 'landing.faq.ai.a' },
		{ q: 'landing.faq.privacy.q', a: 'landing.faq.privacy.a' },
		{ q: 'landing.faq.platforms.q', a: 'landing.faq.platforms.a' }
	];
</script>

<section class="faq" id="faq">
	<h2>{t('landing.faq.title')}</h2>
	{#each FAQ as item (item.q)}
		<details class="faq-item">
			<summary>
				{t(item.q)}
				<span class="chev" aria-hidden="true">▾</span>
			</summary>
			<p>{t(item.a)}</p>
		</details>
	{/each}
</section>

<style>
	.faq {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-width: 720px;
		margin-inline: auto;
		width: 100%;
	}

	.faq h2 {
		text-align: center;
		margin-bottom: var(--space-4);
	}

	.faq-item {
		border-bottom: 1px solid var(--hairline);
		padding-bottom: var(--space-3);
	}

	summary {
		font-weight: 650;
		cursor: pointer;
		min-height: var(--touch-target);
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		list-style: none;
	}

	summary::-webkit-details-marker {
		display: none;
	}

	.chev {
		color: var(--faint);
		flex: none;
		transition: transform var(--dur-base) var(--ease-out-quint);
	}

	details[open] .chev {
		transform: rotate(180deg);
	}

	.faq-item p {
		color: var(--muted);
		padding: var(--space-1) 0 var(--space-3);
		max-width: 62ch;
	}
</style>
