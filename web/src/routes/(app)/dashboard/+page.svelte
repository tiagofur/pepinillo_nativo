<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
</script>

<svelte:head>
	<title>{t('dashboard.title')} · Pepinillo</title>
</svelte:head>

<section class="wip rise-in">
	<h1>{t('dashboard.title')}</h1>
	<p class="subtitle">{t('dashboard.subtitle')}</p>
	<div class="card body">
		<p class="lead">{t('common.wip.title')}</p>
		<p class="muted">{t('common.wip.body')}</p>
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

	.subtitle {
		color: var(--muted);
		margin-top: var(--space-2);
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
</style>
