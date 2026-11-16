<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
</script>

<svelte:head>
	<title>{t('plan.title')} · Pepinillo</title>
</svelte:head>

<section class="wip rise-in">
	<h1>{t('plan.title')}</h1>
	<div class="card body">
		<p class="lead">{t('common.wip.title')}</p>
		<p class="muted">{t('common.wip.body')}</p>
		<ul class="coming">
			<li>{t('plan.filter.today')} · {t('plan.filter.inbox')} · {t('plan.filter.upcoming')}</li>
			<li>{t('plan.energy')} · {t('plan.priority')} · 🍅 · {t('plan.focusTask')}</li>
		</ul>
	</div>
</section>

<style>
	.wip {
		max-width: 560px;
		margin-inline: auto;
		padding-top: var(--space-8);
	}

	h1 {
		font-size: var(--text-xl);
	}

	.body {
		margin-top: var(--space-5);
		padding: var(--space-6);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.lead {
		font-size: var(--text-md);
		font-weight: 650;
	}

	.muted {
		color: var(--muted);
	}

	.coming {
		margin: var(--space-2) 0 0;
		padding-inline-start: var(--space-5);
		color: var(--ink-secondary);
		font-size: var(--text-sm);
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}
</style>
